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
import java.security.KeyStore;

@Configuration
public class WebClientConfig {

    @Value("${client.ssl.key-store}")
    private Resource keyStore;

    @Value("${client.ssl.key-store-password}")
    private String keyStorePassword;

    @Value("${client.ssl.trust-store}")
    private Resource trustStore;

    @Value("${client.ssl.trust-store-password}")
    private String trustStorePassword;

    @Bean
    public WebClient mtlsWebClient() throws Exception {
        // 1. Load Client Identity (KeyManager)
        KeyStore clientKeyStore = KeyStore.getInstance("PKCS12");
        clientKeyStore.load(keyStore.getInputStream(), keyStorePassword.toCharArray());
        
        KeyManagerFactory kmf = KeyManagerFactory.getInstance(KeyManagerFactory.getDefaultAlgorithm());
        kmf.init(clientKeyStore, keyStorePassword.toCharArray());

        // 2. Load Server Trust (TrustManager)
        KeyStore serverTrustStore = KeyStore.getInstance("PKCS12");
        serverTrustStore.load(trustStore.getInputStream(), trustStorePassword.toCharArray());
        
        TrustManagerFactory tmf = TrustManagerFactory.getInstance(TrustManagerFactory.getDefaultAlgorithm());
        tmf.init(serverTrustStore);

        // 3. Build Netty SSL Context using the Factories
        SslContext sslContext = SslContextBuilder.forClient()
                .keyManager(kmf)
                .trustManager(tmf)
                .build();

        // 4. Create the WebClient
        HttpClient httpClient = HttpClient.create()
                .secure(ssl -> ssl.sslContext(sslContext));

        return WebClient.builder()
                .clientConnector(new ReactorClientHttpConnector(httpClient))
                .build();
    }
}
