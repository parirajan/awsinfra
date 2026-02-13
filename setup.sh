#!/bin/bash

# ==========================================
# 0. PREPARE WORKSPACE
# ==========================================
ROOT_DIR="distributed-system-final-noverify"
rm -rf $ROOT_DIR
mkdir -p $ROOT_DIR
cd $ROOT_DIR

# ==========================================
# 1. CERTIFICATE GENERATION
# ==========================================
echo ">>> 1. Generating Certificates..."
mkdir -p certs
cd certs

# 1.1 Root CA
openssl req -x509 -sha256 -days 3650 -newkey rsa:4096 -keyout ca.key -out ca.crt -nodes -subj "/CN=AotiBankRootCA"

# 1.2 Helper Function (Standard Certs)
gen_cert() {
    NAME=$1
    ALIAS=$2
    openssl req -new -newkey rsa:4096 -keyout $NAME.key -out $NAME.csr -nodes -subj "/CN=$NAME"
    # We still add SANs for good measure, but the Client Fix below makes it optional for Get Client
    openssl x509 -req -CA ca.crt -CAkey ca.key -in $NAME.csr -out $NAME.crt -days 365 -CAcreateserial \
    -extensions SAN -extfile <(printf "[SAN]\nsubjectAltName=DNS:$NAME,DNS:localhost,DNS:payments.aotibank.pvt")
    openssl pkcs12 -export -out $NAME.p12 -inkey $NAME.key -in $NAME.crt -certfile ca.crt -passout pass:changeit -name $ALIAS
}

# 1.3 Generate Identities
gen_cert "ingress.payments.aotibank.pvt" "server"
gen_cert "egress.payments.aotibank.pvt" "server"
gen_cert "barterbank.payments.aotibank.pvt" "client"
gen_cert "dispense.payments.aotibank.pvt" "client"

# 1.4 Truststore
keytool -import -trustcacerts -noprompt -alias ca -file ca.crt -keystore truststore.p12 -storepass changeit -storetype PKCS12
keytool -import -noprompt -alias client-public -file barterbank.payments.aotibank.pvt.crt -keystore truststore.p12 -storepass changeit -storetype PKCS12

cd ..

# ==========================================
# 2. INGRESS SERVICE (Node A)
# ==========================================
echo ">>> 2. Creating Ingress Service..."
mkdir -p ingress-service/src/main/java/pvt/aotibank/ingress/{config,controller,model,service}
mkdir -p ingress-service/src/main/resources

# POM
cat << 'EOF' > ingress-service/pom.xml
<project xmlns="http://maven.apache.org/POM/4.0.0" xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><modelVersion>4.0.0</modelVersion>
<parent><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-parent</artifactId><version>3.2.1</version></parent>
<groupId>pvt.aotibank</groupId><artifactId>ingress-service</artifactId><version>1.0.0</version>
<dependencies>
    <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-web</artifactId></dependency>
    <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-security</artifactId></dependency>
    <dependency><groupId>com.ibm.mq</groupId><artifactId>mq-jms-spring-boot-starter</artifactId><version>3.2.1</version></dependency>
</dependencies>
<build><plugins><plugin><groupId>org.springframework.boot</groupId><artifactId>spring-boot-maven-plugin</artifactId></plugin></plugins></build></project>
EOF

# Config
cat << 'EOF' > ingress-service/src/main/resources/application.yml
server:
  port: 8443
  ssl:
    enabled: true
    client-auth: need
    key-store: file:certs/ingress.payments.aotibank.pvt.p12
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

# Security
cat << 'EOF' > ingress-service/src/main/java/pvt/aotibank/ingress/config/SecurityConfig.java
package pvt.aotibank.ingress.config;
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
            if (username.contains("barterbank") || username.equals("client")) {
                return new User(username, "", AuthorityUtils.commaSeparatedStringToAuthorityList("ROLE_USER"));
            }
            throw new UsernameNotFoundException("User not found: " + username);
        };
    }
}
EOF

# Signature Service
cat << 'EOF' > ingress-service/src/main/java/pvt/aotibank/ingress/service/SignatureService.java
package pvt.aotibank.ingress.service;
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

# Controller
cat << 'EOF' > ingress-service/src/main/java/pvt/aotibank/ingress/controller/IngressController.java
package pvt.aotibank.ingress.controller;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.jms.core.JmsTemplate;
import org.springframework.web.bind.annotation.*;
import pvt.aotibank.ingress.service.SignatureService;

record SecurePayload(String messageId, String data, String signature) {}

@RestController
@RequestMapping("/v1/payments")
public class IngressController {
    @Autowired private JmsTemplate jmsTemplate;
    @Autowired private SignatureService signatureService;
    @Value("${ibm.mq.queue}") private String queueName;
    private final ObjectMapper objectMapper = new ObjectMapper();

    @PostMapping("/ingress")
    public ResponseEntity<String> accept(@RequestBody SecurePayload payload) {
        System.out.println(">>> Received Payment: " + payload.messageId());
        if (!signatureService.verify(payload.data(), payload.signature())) {
            return ResponseEntity.status(401).body("Invalid Signature");
        }
        try {
            String jsonMessage = objectMapper.writeValueAsString(payload);
            jmsTemplate.convertAndSend(queueName, jsonMessage);
            return ResponseEntity.accepted().body("Queued");
        } catch (Exception e) { return ResponseEntity.internalServerError().body("MQ Error"); }
    }
}
EOF

# Main App
cat << 'EOF' > ingress-service/src/main/java/pvt/aotibank/ingress/IngressApplication.java
package pvt.aotibank.ingress;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.jms.annotation.EnableJms;
@SpringBootApplication @EnableJms
public class IngressApplication {
    public static void main(String[] args) { SpringApplication.run(IngressApplication.class, args); }
}
EOF

# ==========================================
# 3. EGRESS SERVICE (Node B)
# ==========================================
echo ">>> 3. Creating Egress Service..."
mkdir -p egress-service/src/main/java/pvt/aotibank/egress/{config,controller}
mkdir -p egress-service/src/main/resources

# POM
cp ingress-service/pom.xml egress-service/pom.xml
sed -i 's/ingress-service/egress-service/' egress-service/pom.xml

# Config
cat << 'EOF' > egress-service/src/main/resources/application.yml
server:
  port: 8444
  ssl:
    enabled: true
    client-auth: need
    key-store: file:certs/egress.payments.aotibank.pvt.p12
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

# Security (Allows 'dispense')
cat << 'EOF' > egress-service/src/main/java/pvt/aotibank/egress/config/SecurityConfig.java
package pvt.aotibank.egress.config;
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
            if (username.contains("dispense") || username.equals("client")) {
                return new User(username, "", AuthorityUtils.commaSeparatedStringToAuthorityList("ROLE_USER"));
            }
            throw new UsernameNotFoundException("User not found: " + username);
        };
    }
}
EOF

# Controller
cat << 'EOF' > egress-service/src/main/java/pvt/aotibank/egress/controller/EgressController.java
package pvt.aotibank.egress.controller;
import org.springframework.jms.annotation.JmsListener;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;
import java.io.IOException;
import java.util.concurrent.CopyOnWriteArrayList;

@RestController
@RequestMapping("/v1/payments")
public class EgressController {
    private final CopyOnWriteArrayList<SseEmitter> emitters = new CopyOnWriteArrayList<>();

    @GetMapping(value = "/egress-stream", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public SseEmitter stream() {
        SseEmitter emitter = new SseEmitter(1800000L);
        emitters.add(emitter);
        emitter.onCompletion(() -> emitters.remove(emitter));
        emitter.onTimeout(() -> emitters.remove(emitter));
        System.out.println(">>> Client Connected to Stream.");
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
cat << 'EOF' > egress-service/src/main/java/pvt/aotibank/egress/EgressApplication.java
package pvt.aotibank.egress;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.jms.annotation.EnableJms;
@SpringBootApplication @EnableJms
public class EgressApplication {
    public static void main(String[] args) { SpringApplication.run(EgressApplication.class, args); }
}
EOF

# ==========================================
# 4. PUT CLIENT (Node C)
# ==========================================
echo ">>> 4. Creating Put Client..."
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

# Config
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

# RestConfig (Custom Verifier for Ingress)
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
import javax.net.ssl.HostnameVerifier;
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
                .loadTrustMaterial(trustKeyStore, null)
                .build();

        HostnameVerifier ingressVerifier = (hostname, session) -> {
            try { return session.getPeerPrincipal().getName().contains("ingress.payments.aotibank.pvt"); } 
            catch (Exception e) { return false; }
        };

        CloseableHttpClient httpClient = HttpClients.custom().setConnectionManager(PoolingHttpClientConnectionManagerBuilder.create()
                .setSSLSocketFactory(SSLConnectionSocketFactoryBuilder.create()
                        .setSslContext(sslContext)
                        .setHostnameVerifier(ingressVerifier)
                        .build()).build()).build();
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

# Signer
cat << 'EOF' > put-client/src/main/java/pvt/aotibank/client/put/service/PayloadSigner.java
package pvt.aotibank.client.put.service;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import java.security.*;
import java.util.Base64;
@Service
public class PayloadSigner {
    private final PrivateKey privateKey;
    public PayloadSigner(KeyStore signingKeyStore, 
                         @Value("${client.ssl.key-alias}") String alias) throws Exception {
        this.privateKey = (PrivateKey) signingKeyStore.getKey(alias, "changeit".toCharArray());
    }
    public String sign(String data) throws Exception {
        Signature rsa = Signature.getInstance("SHA256withRSA");
        rsa.initSign(privateKey);
        rsa.update(data.getBytes());
        return Base64.getEncoder().encodeToString(rsa.sign());
    }
}
EOF

# Main App
cat << 'EOF' > put-client/src/main/java/pvt/aotibank/client/put/PutClientApplication.java
package pvt.aotibank.client.put;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.client.RestTemplate;
import pvt.aotibank.client.put.service.PayloadSigner;
import java.util.UUID;

record SecurePayload(String messageId, String data, String signature) {}

@SpringBootApplication
public class PutClientApplication implements CommandLineRunner {
    @Autowired private RestTemplate restTemplate;
    @Autowired private PayloadSigner signer;
    @Value("${ingress.url}") private String url;

    public static void main(String[] args) { SpringApplication.run(PutClientApplication.class, args); }

    @Override
    public void run(String... args) {
        int i = 1;
        while(true) {
            try {
                String data = "{\"amount\": " + (100+i) + ", \"id\": \"PAY-" + i + "\"}";
                String sig = signer.sign(data);
                SecurePayload payload = new SecurePayload(UUID.randomUUID().toString(), data, sig);
                System.out.println(">>> Sending Payment-" + i + "...");
                restTemplate.postForObject(url, payload, String.class);
                System.out.println(">>> SUCCESS");
                i++; Thread.sleep(3000);
            } catch (Exception e) {
                System.err.println(">>> FAILED: " + e.getMessage());
                try { Thread.sleep(5000); } catch (Exception ignored) {}
            }
        }
    }
}
EOF

# ==========================================
# 5. GET CLIENT (Node D)
# ==========================================
echo ">>> 5. Creating Get Client..."
mkdir -p get-client/src/main/java/pvt/aotibank/client/get/config
mkdir -p get-client/src/main/resources

# POM
cat << 'EOF' > get-client/pom.xml
<project xmlns="http://maven.apache.org/POM/4.0.0" xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><modelVersion>4.0.0</modelVersion>
<parent><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-parent</artifactId><version>3.2.1</version></parent>
<groupId>pvt.aotibank</groupId><artifactId>get-client</artifactId><version>1.0.0</version>
<dependencies>
    <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-webflux</artifactId></dependency>
</dependencies>
<build><plugins><plugin><groupId>org.springframework.boot</groupId><artifactId>spring-boot-maven-plugin</artifactId></plugin></plugins></build></project>
EOF

# Config
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
  url: https://payments.aotibank.pvt:8444/v1/payments/egress-stream
EOF

# WebClient Config (THE FIX: USE TCP MODE)
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
import reactor.netty.tcp.SslProvider; // Required for TCP mode

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
        
        // CRITICAL FIX: Use TCP Configuration.
        // This defaults to "Raw TCP" behavior for SSL, effectively disabling 
        // the HTTPS Endpoint Identification (hostname check) while keeping encryption.
        HttpClient httpClient = HttpClient.create()
            .secure(spec -> spec.sslContext(sslContext)
                                .defaultConfiguration(SslProvider.DefaultConfigurationType.TCP));

        return WebClient.builder().clientConnector(new ReactorClientHttpConnector(httpClient)).build();
    }
}
EOF

# Main App
cat << 'EOF' > get-client/src/main/java/pvt/aotibank/client/get/GetClientApplication.java
package pvt.aotibank.client.get;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.reactive.function.client.WebClient;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.http.codec.ServerSentEvent;
import reactor.util.retry.Retry;
import java.time.Duration;

@SpringBootApplication
public class GetClientApplication implements CommandLineRunner {
    @Autowired private WebClient webClient;
    @Value("${egress.url}") private String url;

    public static void main(String[] args) { SpringApplication.run(GetClientApplication.class, args); }

    @Override
    public void run(String... args) {
        System.out.println(">>> Starting Payment Stream Listener...");
        connect();
        try { Thread.currentThread().join(); } catch (Exception e) {}
    }

    private void connect() {
        webClient.get()
                .uri(url)
                .retrieve()
                .bodyToFlux(new ParameterizedTypeReference<ServerSentEvent<String>>() {})
                .retryWhen(Retry.fixedDelay(Long.MAX_VALUE, Duration.ofSeconds(5))
                        .doBeforeRetry(signal -> System.out.println(">>> Connection lost. Retrying in 5s...")))
                .subscribe(
                        event -> System.out.println("[RECEIVED] " + event.data()),
                        error -> System.err.println(">>> Fatal Error: " + error.getMessage())
                );
    }
}
EOF

echo ">>> SETUP COMPLETE!"
echo ">>> Run 'mvn clean package -DskipTests' in each project folder."
