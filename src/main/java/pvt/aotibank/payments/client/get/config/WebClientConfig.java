package pvt.aotibank.payments.client.get.config;

import io.netty.handler.ssl.SslContext;
import io.netty.handler.ssl.SslContextBuilder;
import io.netty.handler.ssl.SslHandler; // <--- IMPORTS ARE CRITICAL
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.io.Resource;
import org.springframework.http.client.reactive.ReactorClientHttpConnector;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.netty.http.client.HttpClient;

import javax.net.ssl.KeyManagerFactory;
import javax.net.ssl.SSLEngine;
import javax.net.ssl.SSLParameters;
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
        System.out.println(">>> Initializing mTLS WebClient...");

        // 1. Load Client Identity
        KeyStore clientKeyStore = KeyStore.getInstance("PKCS12");
        try (InputStream is = keyStore.getInputStream()) {
            clientKeyStore.load(is, keyStorePassword.toCharArray());
        }
        KeyManagerFactory kmf = KeyManagerFactory.getInstance(KeyManagerFactory.getDefaultAlgorithm());
        kmf.init(clientKeyStore, keyStorePassword.toCharArray());

        // 2. Load TrustStore
        KeyStore serverTrustStore = KeyStore.getInstance("PKCS12");
        try (InputStream is = trustStore.getInputStream()) {
            serverTrustStore.load(is, trustStorePassword.toCharArray());
        }
        TrustManagerFactory tmf = TrustManagerFactory.getInstance(TrustManagerFactory.getDefaultAlgorithm());
        tmf.init(serverTrustStore);

        // 3. Build SSL Context
        SslContext sslContext = SslContextBuilder.forClient()
                .keyManager(kmf)
                .trustManager(tmf)
                .build();

        // 4. HttpClient with Hostname Verification DISABLED
        // Uses 'doOnConnected' which works in ALL versions
        HttpClient httpClient = HttpClient.create()
                .secure(ssl -> ssl.sslContext(sslContext))
                .doOnConnected(conn -> {
                    // This block runs when the connection connects
                    System.out.println(">>> Connection Established. Disabling Hostname Verification...");
                    SslHandler sslHandler = conn.channel().pipeline().get(SslHandler.class);
                    if (sslHandler != null) {
                        SSLEngine engine = sslHandler.engine();
                        SSLParameters params = engine.getSSLParameters();
                        
                        // This effectively disables the 'localhost' vs 'server' mismatch check
                        params.setEndpointIdentificationAlgorithm(null); 
                        
                        engine.setSSLParameters(params);
                    }
                });

        return WebClient.builder()
                .clientConnector(new ReactorClientHttpConnector(httpClient))
                .build();
    }
}
