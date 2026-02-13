#!/bin/bash

# ==========================================
# 0. PREPARE WORKSPACE
# ==========================================
ROOT_DIR="unified-payment-system"
rm -rf $ROOT_DIR
mkdir -p $ROOT_DIR
cd $ROOT_DIR

# ==========================================
# 1. CERTIFICATE GENERATION
# ==========================================
echo ">>> 1. Generating Unified Certificates..."
mkdir -p certs
cd certs

# Root CA
openssl req -x509 -sha256 -days 3650 -newkey rsa:4096 -keyout ca.key -out ca.crt -nodes -subj "/CN=AotiBankRootCA"

# Helper Function
gen_cert() {
    NAME=$1
    ALIAS=$2
    openssl req -new -newkey rsa:4096 -keyout $NAME.key -out $NAME.csr -nodes -subj "/CN=$NAME"
    # Unified Cert for the Gateway (supports 'payments' DNS and 'gateway' DNS)
    openssl x509 -req -CA ca.crt -CAkey ca.key -in $NAME.csr -out $NAME.crt -days 365 -CAcreateserial \
    -extensions SAN -extfile <(printf "[SAN]\nsubjectAltName=DNS:$NAME,DNS:localhost,DNS:payments.aotibank.pvt,DNS:gateway.payments.aotibank.pvt")
    openssl pkcs12 -export -out $NAME.p12 -inkey $NAME.key -in $NAME.crt -certfile ca.crt -passout pass:changeit -name $ALIAS
}

# Generate Identities
gen_cert "gateway.payments.aotibank.pvt" "server"  # <--- THE NEW UNIFIED SERVER
gen_cert "barterbank.payments.aotibank.pvt" "client"
gen_cert "dispense.payments.aotibank.pvt" "client"

# Truststore
keytool -import -trustcacerts -noprompt -alias ca -file ca.crt -keystore truststore.p12 -storepass changeit -storetype PKCS12
keytool -import -noprompt -alias client-public -file barterbank.payments.aotibank.pvt.crt -keystore truststore.p12 -storepass changeit -storetype PKCS12

cd ..

# ==========================================
# 2. UNIFIED GATEWAY SERVICE (Ingress + Egress Merged)
# ==========================================
echo ">>> 2. Creating Unified Gateway Service..."
mkdir -p gateway-service/src/main/java/pvt/aotibank/gateway/{config,controller,service}
mkdir -p gateway-service/src/main/resources

# POM
cat << 'EOF' > gateway-service/pom.xml
<project xmlns="http://maven.apache.org/POM/4.0.0" xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><modelVersion>4.0.0</modelVersion>
<parent><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-parent</artifactId><version>3.2.1</version></parent>
<groupId>pvt.aotibank</groupId><artifactId>gateway-service</artifactId><version>1.0.0</version>
<dependencies>
    <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-web</artifactId></dependency>
    <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-security</artifactId></dependency>
    <dependency><groupId>com.ibm.mq</groupId><artifactId>mq-jms-spring-boot-starter</artifactId><version>3.2.1</version></dependency>
</dependencies>
<build><plugins><plugin><groupId>org.springframework.boot</groupId><artifactId>spring-boot-maven-plugin</artifactId></plugin></plugins></build></project>
EOF

# Config (Single Port 8443)
cat << 'EOF' > gateway-service/src/main/resources/application.yml
server:
  port: 8443
  ssl:
    enabled: true
    client-auth: need
    key-store: file:certs/gateway.payments.aotibank.pvt.p12
    key-store-password: changeit
    trust-store: file:certs/truststore.p12
    trust-store-password: changeit
ibm:
  mq:
    queue-manager: QM1
    channel: DEV.APP.SVRCONN
    conn-name: ibm-mq-server(1414)
    user: mqm
    queue: PAYMENT.QUEUE.IN
EOF

# Security (Allows BOTH clients)
cat << 'EOF' > gateway-service/src/main/java/pvt/aotibank/gateway/config/SecurityConfig.java
package pvt.aotibank.gateway.config;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.core.authority.AuthorityUtils;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
public class SecurityConfig {
    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http.csrf(AbstractHttpConfigurer::disable)
            .authorizeHttpRequests(auth -> auth.anyRequest().authenticated())
            .x509(x509 -> x509.subjectPrincipalRegex("CN=(.*?)(?:,|$)"));
        return http.build();
    }
    @Bean
    public UserDetailsService userDetailsService() {
        return username -> {
            // Allow both Put Client (barterbank) and Get Client (dispense)
            if (username.contains("barterbank") || username.contains("dispense") || username.equals("client")) {
                return new User(username, "", AuthorityUtils.commaSeparatedStringToAuthorityList("ROLE_USER"));
            }
            throw new UsernameNotFoundException("User not found: " + username);
        };
    }
}
EOF

# Signature Service
cat << 'EOF' > gateway-service/src/main/java/pvt/aotibank/gateway/service/SignatureService.java
package pvt.aotibank.gateway.service;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.Resource;
import org.springframework.stereotype.Service;
import java.io.InputStream;
import java.security.*;
import java.security.cert.Certificate;
import java.util.Base64;

@Service
public class SignatureService {
    private final PublicKey clientPublicKey;
    public SignatureService(@Value("${server.ssl.trust-store}") Resource trustStore,
                            @Value("${server.ssl.trust-store-password}") String password) throws Exception {
        KeyStore ks = KeyStore.getInstance("PKCS12");
        try (InputStream is = trustStore.getInputStream()) { ks.load(is, password.toCharArray()); }
        Certificate cert = ks.getCertificate("client-public");
        this.clientPublicKey = cert.getPublicKey();
    }
    public boolean verify(String data, String signature) {
        try {
            Signature sig = Signature.getInstance("SHA256withRSA");
            sig.initVerify(clientPublicKey);
            sig.update(data.getBytes());
            return sig.verify(Base64.getDecoder().decode(signature));
        } catch (Exception e) { return false; }
    }
}
EOF

# Unified Controller (Both Ingress & Egress Logic)
cat << 'EOF' > gateway-service/src/main/java/pvt/aotibank/gateway/controller/PaymentController.java
package pvt.aotibank.gateway.controller;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.jms.annotation.JmsListener;
import org.springframework.jms.core.JmsTemplate;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;
import pvt.aotibank.gateway.service.SignatureService;
import java.io.IOException;
import java.util.concurrent.CopyOnWriteArrayList;

record SecurePayload(String messageId, String data, String signature) {}

@RestController
@RequestMapping("/v1/payments")
public class PaymentController {
    // --- INGRESS LOGIC ---
    @Autowired private JmsTemplate jmsTemplate;
    @Autowired private SignatureService signatureService;
    @Value("${ibm.mq.queue}") private String queueName;
    private final ObjectMapper objectMapper = new ObjectMapper();

    @PostMapping("/ingress")
    public ResponseEntity<String> accept(@RequestBody SecurePayload payload) {
        System.out.println(">>> [INGRESS] Received Payment: " + payload.messageId());
        if (!signatureService.verify(payload.data(), payload.signature())) {
            return ResponseEntity.status(401).body("Invalid Signature");
        }
        try {
            String jsonMessage = objectMapper.writeValueAsString(payload);
            jmsTemplate.convertAndSend(queueName, jsonMessage);
            return ResponseEntity.accepted().body("Queued");
        } catch (Exception e) { return ResponseEntity.internalServerError().body("MQ Error"); }
    }

    // --- EGRESS LOGIC ---
    private final CopyOnWriteArrayList<SseEmitter> emitters = new CopyOnWriteArrayList<>();

    @GetMapping(value = "/egress-stream", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public SseEmitter stream() {
        SseEmitter emitter = new SseEmitter(1800000L);
        emitters.add(emitter);
        emitter.onCompletion(() -> emitters.remove(emitter));
        emitter.onTimeout(() -> emitters.remove(emitter));
        System.out.println(">>> [EGRESS] Client Connected to Stream.");
        return emitter;
    }

    @JmsListener(destination = "${ibm.mq.queue}")
    public void onMessage(String fullPayloadJson) {
        for (SseEmitter emitter : emitters) {
            try { emitter.send(SseEmitter.event().data(fullPayloadJson)); } 
            catch (IOException e) { emitters.remove(emitter); }
        }
    }
}
EOF

# Main App
cat << 'EOF' > gateway-service/src/main/java/pvt/aotibank/gateway/GatewayApplication.java
package pvt.aotibank.gateway;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.jms.annotation.EnableJms;
@SpringBootApplication @EnableJms
public class GatewayApplication {
    public static void main(String[] args) { SpringApplication.run(GatewayApplication.class, args); }
}
EOF

# ==========================================
# 3. PUT CLIENT (Updated URL)
# ==========================================
echo ">>> 3. Creating Put Client..."
mkdir -p put-client/src/main/java/pvt/aotibank/client/put/{config,service}
mkdir -p put-client/src/main/resources

# POM
cat << 'EOF' > put-client/pom.xml
<project xmlns="http://maven.apache.org/POM/4.0.0" xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><modelVersion>4.0.0</modelVersion>
<parent><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-parent</artifactId><version>3.2.1</version></parent>
<groupId>pvt.aotibank</groupId><artifactId>put-client</artifactId><version>1.0.0</version>
<dependencies>
    <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-web</artifactId></dependency>
    <dependency><groupId>org.apache.httpcomponents.client5</groupId><artifactId>httpclient5</artifactId><version>5.2.1</version></dependency>
</dependencies>
<build><plugins><plugin><groupId>org.springframework.boot</groupId><artifactId>spring-boot-maven-plugin</artifactId></plugin></plugins></build></project>
EOF

# Config (Same Port 8443 for both clients now)
cat << 'EOF' > put-client/src/main/resources/application.yml
client:
  ssl:
    key-store: file:certs/barterbank.payments.aotibank.pvt.p12
    key-store-password: changeit
    trust-store: file:certs/truststore.p12
    trust-store-password: changeit
    key-alias: client
ingress:
  url: https://payments.aotibank.pvt:8443/v1/payments/ingress
EOF

# RestConfig (Standard mTLS - Gateway Cert is 'Correct')
cat << 'EOF' > put-client/src/main/java/pvt/aotibank/client/put/config/RestClientConfig.java
package pvt.aotibank.client.put.config;
import org.apache.hc.client5.http.impl.classic.CloseableHttpClient;
import org.apache.hc.client5.http.impl.classic.HttpClients;
import org.apache.hc.client5.http.impl.io.PoolingHttpClientConnectionManagerBuilder;
import org.apache.hc.client5.http.ssl.SSLConnectionSocketFactoryBuilder;
import org.apache.hc.core5.ssl.SSLContextBuilder;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.io.Resource;
import org.springframework.http.client.HttpComponentsClientHttpRequestFactory;
import org.springframework.web.client.RestTemplate;
import javax.net.ssl.SSLContext;
import java.io.InputStream;
import java.security.KeyStore;

@Configuration
public class RestClientConfig {
    @Value("${client.ssl.key-store}") private Resource keyStore;
    @Value("${client.ssl.key-store-password}") private String keyStorePassword;
    @Value("${client.ssl.trust-store}") private Resource trustStore;
    @Value("${client.ssl.trust-store-password}") private String trustStorePassword;

    @Bean
    public RestTemplate mtlsRestTemplate() throws Exception {
        KeyStore clientKeyStore = KeyStore.getInstance("PKCS12");
        try (InputStream is = keyStore.getInputStream()) { clientKeyStore.load(is, keyStorePassword.toCharArray()); }
        KeyStore trustKeyStore = KeyStore.getInstance("PKCS12");
        try (InputStream is = trustStore.getInputStream()) { trustKeyStore.load(is, trustStorePassword.toCharArray()); }

        SSLContext sslContext = SSLContextBuilder.create()
                .loadKeyMaterial(clientKeyStore, keyStorePassword.toCharArray())
                .loadTrustMaterial(trustKeyStore, null).build();
        
        CloseableHttpClient httpClient = HttpClients.custom().setConnectionManager(PoolingHttpClientConnectionManagerBuilder.create()
                .setSSLSocketFactory(SSLConnectionSocketFactoryBuilder.create().setSslContext(sslContext).build()).build()).build();
        return new RestTemplate(new HttpComponentsClientHttpRequestFactory(httpClient));
    }
    @Bean
    public KeyStore signingKeyStore() throws Exception {
        KeyStore ks = KeyStore.getInstance("PKCS12");
        try (InputStream is = keyStore.getInputStream()) { ks.load(is, keyStorePassword.toCharArray()); }
        return ks;
    }
}
EOF

# Signer & Main App (Omitting logic for brevity - assume standard from previous)
# ... (Same as before, copy PayloadSigner.java and PutClientApplication.java) ...

# ==========================================
# 4. GET CLIENT (Updated URL)
# ==========================================
echo ">>> 4. Creating Get Client..."
mkdir -p get-client/src/main/java/pvt/aotibank/client/get/config
mkdir -p get-client/src/main/resources

# POM (Standard)
cat << 'EOF' > get-client/pom.xml
<project xmlns="http://maven.apache.org/POM/4.0.0" xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><modelVersion>4.0.0</modelVersion>
<parent><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-parent</artifactId><version>3.2.1</version></parent>
<groupId>pvt.aotibank</groupId><artifactId>get-client</artifactId><version>1.0.0</version>
<dependencies>
    <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-webflux</artifactId></dependency>
</dependencies>
<build><plugins><plugin><groupId>org.springframework.boot</groupId><artifactId>spring-boot-maven-plugin</artifactId></plugin></plugins></build></project>
EOF

# Config (Same Port 8443)
cat << 'EOF' > get-client/src/main/resources/application.yml
server:
  port: 8082
client:
  ssl:
    key-store: file:certs/dispense.payments.aotibank.pvt.p12
    key-store-password: changeit
    trust-store: file:certs/truststore.p12
    trust-store-password: changeit
egress:
  url: https://payments.aotibank.pvt:8443/v1/payments/egress-stream
EOF

# WebClient Config (Standard - No TCP hack needed)
cat << 'EOF' > get-client/src/main/java/pvt/aotibank/client/get/config/WebClientConfig.java
package pvt.aotibank.client.get.config;
import io.netty.handler.ssl.SslContext;
import io.netty.handler.ssl.SslContextBuilder;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.io.Resource;
import org.springframework.http.client.reactive.ReactorClientHttpConnector;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.netty.http.client.HttpClient;
import javax.net.ssl.KeyManagerFactory;
import javax.net.ssl.TrustManagerFactory;
import java.io.InputStream;
import java.security.KeyStore;

@Configuration
public class WebClientConfig {
    @Value("${client.ssl.key-store}") private Resource keyStore;
    @Value("${client.ssl.key-store-password}") private String keyStorePassword;
    @Value("${client.ssl.trust-store}") private Resource trustStore;
    @Value("${client.ssl.trust-store-password}") private String trustStorePassword;

    @Bean
    public WebClient mtlsWebClient() throws Exception {
        KeyStore clientKeyStore = KeyStore.getInstance("PKCS12");
        try (InputStream is = keyStore.getInputStream()) { clientKeyStore.load(is, keyStorePassword.toCharArray()); }
        KeyManagerFactory kmf = KeyManagerFactory.getInstance(KeyManagerFactory.getDefaultAlgorithm());
        kmf.init(clientKeyStore, keyStorePassword.toCharArray());

        KeyStore serverTrustStore = KeyStore.getInstance("PKCS12");
        try (InputStream is = trustStore.getInputStream()) { serverTrustStore.load(is, trustStorePassword.toCharArray()); }
        TrustManagerFactory tmf = TrustManagerFactory.getInstance(TrustManagerFactory.getDefaultAlgorithm());
        tmf.init(serverTrustStore);

        SslContext sslContext = SslContextBuilder.forClient().keyManager(kmf).trustManager(tmf).build();
        HttpClient httpClient = HttpClient.create().secure(ssl -> ssl.sslContext(sslContext));
        return WebClient.builder().clientConnector(new ReactorClientHttpConnector(httpClient)).build();
    }
}
EOF

# Main App (Copy Retry Logic from previous)
# ... (Assume GetClientApplication.java is copied here) ...

echo ">>> SETUP COMPLETE. Deploy 'gateway-service' as your single backend."
