#!/bin/bash

# ==========================================
# 0. CLEAN SLATE
# ==========================================
echo ">>> Cleaning up old directories..."
rm -rf mq-distributed-system aotibank-clients certs generate-certs.sh

# ==========================================
# 1. CREATE DIRECTORY STRUCTURE
# ==========================================
echo ">>> Creating Folder Structure..."
mkdir -p mq-distributed-system/ingress-service/src/main/java/pvt/aotibank/payments/ingress/config
mkdir -p mq-distributed-system/ingress-service/src/main/java/pvt/aotibank/payments/ingress/controller
mkdir -p mq-distributed-system/ingress-service/src/main/java/pvt/aotibank/payments/ingress/model
mkdir -p mq-distributed-system/ingress-service/src/main/java/pvt/aotibank/payments/ingress/service
mkdir -p mq-distributed-system/ingress-service/src/main/resources

mkdir -p mq-distributed-system/egress-service/src/main/java/pvt/aotibank/payments/egress/config
mkdir -p mq-distributed-system/egress-service/src/main/java/pvt/aotibank/payments/egress/controller
mkdir -p mq-distributed-system/egress-service/src/main/resources

mkdir -p aotibank-clients/put-client/src/main/java/pvt/aotibank/payments/client/put/config
mkdir -p aotibank-clients/put-client/src/main/java/pvt/aotibank/payments/client/put/service
mkdir -p aotibank-clients/put-client/src/main/resources

mkdir -p aotibank-clients/get-client/src/main/java/pvt/aotibank/payments/client/get/config
mkdir -p aotibank-clients/get-client/src/main/java/pvt/aotibank/payments/client/get/service
mkdir -p aotibank-clients/get-client/src/main/resources

# ==========================================
# 2. CERTIFICATE GENERATION (FIXED ALIASES)
# ==========================================
echo ">>> generating certificates with correct aliases..."
mkdir -p certs
cd certs

# CA
openssl req -x509 -sha256 -days 3650 -newkey rsa:4096 -keyout ca.key -out ca.crt -nodes -subj "/CN=AotiBankRootCA"

# SERVER (Ingress) - Note the '-name server'
openssl req -new -newkey rsa:4096 -keyout server.key -out server.csr -nodes -subj "/CN=server"
openssl x509 -req -CA ca.crt -CAkey ca.key -in server.csr -out server.crt -days 365 -CAcreateserial
openssl pkcs12 -export -out server-keystore.p12 -inkey server.key -in server.crt -certfile ca.crt -passout pass:changeit -name server

# CLIENT (Put/Get) - Note the '-name client' (Fixes 'Key must not be null')
openssl req -new -newkey rsa:4096 -keyout client.key -out client.csr -nodes -subj "/CN=client"
openssl x509 -req -CA ca.crt -CAkey ca.key -in client.csr -out client.crt -days 365
openssl pkcs12 -export -out client-keystore.p12 -inkey client.key -in client.crt -certfile ca.crt -passout pass:password -name client

# TRUSTSTORE
keytool -import -trustcacerts -noprompt -alias ca -file ca.crt -keystore truststore.p12 -storepass changeit -storetype PKCS12
keytool -import -noprompt -alias client-public -file client.crt -keystore truststore.p12 -storepass changeit -storetype PKCS12

cd ..

# ==========================================
# 3. INGRESS SERVICE FILES
# ==========================================
echo ">>> Writing Ingress Service..."

cat << 'EOF' > mq-distributed-system/ingress-service/pom.xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    <parent><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-parent</artifactId><version>3.2.1</version><relativePath/></parent>
    <groupId>pvt.aotibank.payments</groupId><artifactId>ingress-service</artifactId><version>1.0.0</version>
    <properties><java.version>17</java.version></properties>
    <dependencies>
        <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-web</artifactId></dependency>
        <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-security</artifactId></dependency>
        <dependency><groupId>com.ibm.mq</groupId><artifactId>mq-jms-spring-boot-starter</artifactId><version>3.2.1</version></dependency>
        <dependency><groupId>com.fasterxml.jackson.core</groupId><artifactId>jackson-databind</artifactId></dependency>
    </dependencies>
    <build><plugins><plugin><groupId>org.springframework.boot</groupId><artifactId>spring-boot-maven-plugin</artifactId></plugin></plugins></build>
</project>
EOF

# Config with RELATIVE FILE PATHS
cat << 'EOF' > mq-distributed-system/ingress-service/src/main/resources/application.yml
server:
  port: 8443
  ssl:
    enabled: true
    client-auth: need
    key-store: file:certs/server-keystore.p12
    key-store-password: changeit
    trust-store: file:certs/truststore.p12
    trust-store-password: changeit
ibm:
  mq:
    queue-manager: QM1
    channel: DEV.APP.SVRCONN
    conn-name: localhost(1414)
    user: admin
    password: password
    queue: PAYMENT.QUEUE.IN
EOF

cat << 'EOF' > mq-distributed-system/ingress-service/src/main/java/pvt/aotibank/payments/ingress/IngressApplication.java
package pvt.aotibank.payments.ingress;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.jms.annotation.EnableJms;
@SpringBootApplication @EnableJms
public class IngressApplication {
    public static void main(String[] args) { SpringApplication.run(IngressApplication.class, args); }
}
EOF

cat << 'EOF' > mq-distributed-system/ingress-service/src/main/java/pvt/aotibank/payments/ingress/config/SecurityConfig.java
package pvt.aotibank.payments.ingress.config;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
@Configuration
public class SecurityConfig {
    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http.csrf(AbstractHttpConfigurer::disable)
            .authorizeHttpRequests(auth -> auth.anyRequest().authenticated())
            .x509(x509 -> x509.subjectPrincipalRegex("CN=(.*?)(?:,|$)"));
        return http.build();
    }
}
EOF

cat << 'EOF' > mq-distributed-system/ingress-service/src/main/java/pvt/aotibank/payments/ingress/model/SecurePayload.java
package pvt.aotibank.payments.ingress.model;
public record SecurePayload(String messageId, String data, String signature) {}
EOF

cat << 'EOF' > mq-distributed-system/ingress-service/src/main/java/pvt/aotibank/payments/ingress/service/SignatureService.java
package pvt.aotibank.payments.ingress.service;
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
        if (cert == null) throw new RuntimeException("Client Public Key 'client-public' not found in TrustStore");
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

cat << 'EOF' > mq-distributed-system/ingress-service/src/main/java/pvt/aotibank/payments/ingress/controller/IngressController.java
package pvt.aotibank.payments.ingress.controller;
import com.fasterxml.jackson.databind.ObjectMapper;
import pvt.aotibank.payments.ingress.model.SecurePayload;
import pvt.aotibank.payments.ingress.service.SignatureService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.jms.core.JmsTemplate;
import org.springframework.web.bind.annotation.*;
@RestController
@RequestMapping("/v1/payments")
public class IngressController {
    @Autowired private JmsTemplate jmsTemplate;
    @Autowired private SignatureService signatureService;
    @Value("${ibm.mq.queue}") private String queueName;
    private final ObjectMapper objectMapper = new ObjectMapper();
    @PostMapping("/ingress")
    public ResponseEntity<String> accept(@RequestBody SecurePayload payload) {
        if (!signatureService.verify(payload.data(), payload.signature())) {
            return ResponseEntity.status(401).body("Invalid Signature");
        }
        try {
            String jsonMessage = objectMapper.writeValueAsString(payload);
            jmsTemplate.convertAndSend(queueName, jsonMessage);
            return ResponseEntity.accepted().body("Queued: " + payload.messageId());
        } catch (Exception e) { return ResponseEntity.internalServerError().body("MQ Error: " + e.getMessage()); }
    }
}
EOF

# ==========================================
# 4. EGRESS SERVICE FILES
# ==========================================
echo ">>> Writing Egress Service..."

cat << 'EOF' > mq-distributed-system/egress-service/pom.xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    <parent><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-parent</artifactId><version>3.2.1</version><relativePath/></parent>
    <groupId>pvt.aotibank.payments</groupId><artifactId>egress-service</artifactId><version>1.0.0</version>
    <properties><java.version>17</java.version></properties>
    <dependencies>
        <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-web</artifactId></dependency>
        <dependency><groupId>com.ibm.mq</groupId><artifactId>mq-jms-spring-boot-starter</artifactId><version>3.2.1</version></dependency>
    </dependencies>
    <build><plugins><plugin><groupId>org.springframework.boot</groupId><artifactId>spring-boot-maven-plugin</artifactId></plugin></plugins></build>
</project>
EOF

cat << 'EOF' > mq-distributed-system/egress-service/src/main/resources/application.yml
server:
  port: 8444
  ssl:
    enabled: true
    client-auth: need
    key-store: file:certs/server-keystore.p12
    key-store-password: changeit
    trust-store: file:certs/truststore.p12
    trust-store-password: changeit
ibm:
  mq:
    queue-manager: QM1
    channel: DEV.APP.SVRCONN
    conn-name: localhost(1414)
    user: admin
    password: password
    queue: PAYMENT.QUEUE.IN
EOF

cat << 'EOF' > mq-distributed-system/egress-service/src/main/java/pvt/aotibank/payments/egress/EgressApplication.java
package pvt.aotibank.payments.egress;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.jms.annotation.EnableJms;
@SpringBootApplication @EnableJms
public class EgressApplication {
    public static void main(String[] args) { SpringApplication.run(EgressApplication.class, args); }
}
EOF

cat << 'EOF' > mq-distributed-system/egress-service/src/main/java/pvt/aotibank/payments/egress/controller/EgressController.java
package pvt.aotibank.payments.egress.controller;
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

# ==========================================
# 5. PUT CLIENT FILES
# ==========================================
echo ">>> Writing Put Client..."

cat << 'EOF' > aotibank-clients/put-client/pom.xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    <parent><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-parent</artifactId><version>3.2.1</version><relativePath/></parent>
    <groupId>pvt.aotibank.payments.client</groupId><artifactId>put-client</artifactId><version>1.0.0</version>
    <properties><java.version>17</java.version></properties>
    <dependencies>
        <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-web</artifactId></dependency>
        <dependency><groupId>org.apache.httpcomponents.client5</groupId><artifactId>httpclient5</artifactId><version>5.2.1</version></dependency>
    </dependencies>
    <build><plugins><plugin><groupId>org.springframework.boot</groupId><artifactId>spring-boot-maven-plugin</artifactId></plugin></plugins></build>
</project>
EOF

# Config with RELATIVE FILE PATHS
cat << 'EOF' > aotibank-clients/put-client/src/main/resources/application.yml
client:
  ssl:
    key-store: file:certs/client-keystore.p12
    key-store-password: password
    key-alias: client
    trust-store: file:certs/truststore.p12
    trust-store-password: changeit
ingress:
  url: https://localhost:8443/v1/payments/ingress
EOF

cat << 'EOF' > aotibank-clients/put-client/src/main/java/pvt/aotibank/payments/client/put/PutClientApplication.java
package pvt.aotibank.payments.client.put;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;
import pvt.aotibank.payments.client.put.service.PaymentSender;
@SpringBootApplication
public class PutClientApplication {
    public static void main(String[] args) { SpringApplication.run(PutClientApplication.class, args); }
    @Bean
    CommandLineRunner run(PaymentSender sender) {
        return args -> {
            System.out.println(">>> Sending Test Payment...");
            sender.send("{\"amount\": 5000, \"currency\": \"USD\", \"account\": \"123456\"}");
        };
    }
}
EOF

cat << 'EOF' > aotibank-clients/put-client/src/main/java/pvt/aotibank/payments/client/put/config/RestClientConfig.java
package pvt.aotibank.payments.client.put.config;
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
                .loadTrustMaterial(trustKeyStore, null)
                .build();
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

cat << 'EOF' > aotibank-clients/put-client/src/main/java/pvt/aotibank/payments/client/put/service/PayloadSigner.java
package pvt.aotibank.payments.client.put.service;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import java.security.*;
import java.util.Base64;
@Service
public class PayloadSigner {
    private final PrivateKey privateKey;
    public PayloadSigner(KeyStore signingKeyStore, 
                         @Value("${client.ssl.key-store-password}") String password,
                         @Value("${client.ssl.key-alias}") String alias) throws Exception {
        this.privateKey = (PrivateKey) signingKeyStore.getKey(alias, password.toCharArray());
        // FIX: Explicit check to prevent Key Null error
        if (this.privateKey == null) {
            throw new RuntimeException("CRITICAL ERROR: No private key found for alias '" + alias + "'. Please check keystore generation.");
        }
    }
    public String sign(String data) throws Exception {
        Signature rsa = Signature.getInstance("SHA256withRSA");
        rsa.initSign(privateKey);
        rsa.update(data.getBytes());
        return Base64.getEncoder().encodeToString(rsa.sign());
    }
}
EOF

cat << 'EOF' > aotibank-clients/put-client/src/main/java/pvt/aotibank/payments/client/put/service/PaymentSender.java
package pvt.aotibank.payments.client.put.service;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;
import java.util.UUID;
record SecurePayload(String messageId, String data, String signature) {}
@Service
public class PaymentSender {
    private final RestTemplate restTemplate;
    private final PayloadSigner signer;
    @Value("${ingress.url}") private String ingressUrl;
    public PaymentSender(RestTemplate mtlsRestTemplate, PayloadSigner signer) {
        this.restTemplate = mtlsRestTemplate;
        this.signer = signer;
    }
    public void send(String json) {
        try {
            String sig = signer.sign(json);
            SecurePayload payload = new SecurePayload(UUID.randomUUID().toString(), json, sig);
            restTemplate.postForObject(ingressUrl, payload, String.class);
            System.out.println("Sent Payment: " + payload.messageId());
        } catch (Exception e) { e.printStackTrace(); }
    }
}
EOF

# ==========================================
# 6. GET CLIENT FILES
# ==========================================
echo ">>> Writing Get Client..."

cat << 'EOF' > aotibank-clients/get-client/pom.xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    <parent><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-parent</artifactId><version>3.2.1</version><relativePath/></parent>
    <groupId>pvt.aotibank.payments.client</groupId><artifactId>get-client</artifactId><version>1.0.0</version>
    <properties><java.version>17</java.version></properties>
    <dependencies>
        <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-webflux</artifactId></dependency>
    </dependencies>
    <build><plugins><plugin><groupId>org.springframework.boot</groupId><artifactId>spring-boot-maven-plugin</artifactId></plugin></plugins></build>
</project>
EOF

# Config with RELATIVE FILE PATHS
cat << 'EOF' > aotibank-clients/get-client/src/main/resources/application.yml
client:
  ssl:
    key-store: file:certs/client-keystore.p12
    key-store-password: password
    trust-store: file:certs/truststore.p12
    trust-store-password: changeit
egress:
  url: https://localhost:8444/v1/payments/egress-stream
EOF

cat << 'EOF' > aotibank-clients/get-client/src/main/java/pvt/aotibank/payments/client/get/GetClientApplication.java
package pvt.aotibank.payments.client.get;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import pvt.aotibank.payments.client.get.service.SseListener;
import org.springframework.context.ApplicationContext;
@SpringBootApplication
public class GetClientApplication {
    public static void main(String[] args) {
        ApplicationContext context = SpringApplication.run(GetClientApplication.class, args);
        context.getBean(SseListener.class).startListening();
    }
}
EOF

cat << 'EOF' > aotibank-clients/get-client/src/main/java/pvt/aotibank/payments/client/get/config/WebClientConfig.java
package pvt.aotibank.payments.client.get.config;
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

cat << 'EOF' > aotibank-clients/get-client/src/main/java/pvt/aotibank/payments/client/get/service/PayloadVerifier.java
package pvt.aotibank.payments.client.get.service;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.Resource;
import org.springframework.stereotype.Service;
import java.io.InputStream;
import java.security.*;
import java.security.cert.Certificate;
import java.util.Base64;
@Service
public class PayloadVerifier {
    private final PublicKey clientPublicKey;
    public PayloadVerifier(@Value("${client.ssl.trust-store}") Resource trustStore,
                           @Value("${client.ssl.trust-store-password}") String password) throws Exception {
        KeyStore ks = KeyStore.getInstance("PKCS12");
        try (InputStream is = trustStore.getInputStream()) { ks.load(is, password.toCharArray()); }
        Certificate cert = ks.getCertificate("client-public");
        if (cert == null) throw new RuntimeException("Client Public Key 'client-public' not found in TrustStore");
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

cat << 'EOF' > aotibank-clients/get-client/src/main/java/pvt/aotibank/payments/client/get/service/SseListener.java
package pvt.aotibank.payments.client.get.service;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.http.codec.ServerSentEvent;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.core.publisher.Flux;
record SecurePayload(String messageId, String data, String signature) {}
@Service
public class SseListener {
    private final WebClient webClient;
    private final PayloadVerifier verifier;
    private final ObjectMapper mapper = new ObjectMapper();
    @Value("${egress.url}") private String egressUrl;
    public SseListener(WebClient mtlsWebClient, PayloadVerifier verifier) {
        this.webClient = mtlsWebClient;
        this.verifier = verifier;
    }
    public void startListening() {
        System.out.println("Connecting to Stream...");
        Flux<ServerSentEvent<String>> stream = webClient.get()
                .uri(egressUrl).retrieve().bodyToFlux(new ParameterizedTypeReference<>() {});
        stream.subscribe(event -> {
            try {
                SecurePayload payload = mapper.readValue(event.data(), SecurePayload.class);
                if (verifier.verify(payload.data(), payload.signature())) {
                    System.out.println("[VERIFIED] Received: " + payload.data());
                } else { System.err.println("[WARNING] Signature Failed!"); }
            } catch (Exception e) { System.err.println("Parse Error: " + e.getMessage()); }
        });
        try { Thread.currentThread().join(); } catch (Exception e) {}
    }
}
EOF

echo ">>> Setup Complete."
echo ">>> Now build everything: 'mvn clean package -DskipTests' in each project folder."
echo ">>> IMPORTANT: Run all jars from THIS root directory so 'certs/' folder is visible."
