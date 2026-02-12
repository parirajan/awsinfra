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
        // Build Netty SSL Context for WebFlux
        SslContext sslContext = SslContextBuilder.forClient()
                .keyManager(keyStore.getFile(), keyStorePassword.toCharArray())
                .trustManager(trustStore.getFile()) 
                .build();

        HttpClient httpClient = HttpClient.create()
                .secure(ssl -> ssl.sslContext(sslContext));

        return WebClient.builder()
                .clientConnector(new ReactorClientHttpConnector(httpClient))
                .build();
    }
}
