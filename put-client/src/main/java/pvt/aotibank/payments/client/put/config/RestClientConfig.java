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

    @Value("${client.ssl.key-store}")
    private Resource keyStore;

    @Value("${client.ssl.key-store-password}")
    private String keyStorePassword;

    @Value("${client.ssl.trust-store}")
    private Resource trustStore;

    @Value("${client.ssl.trust-store-password}")
    private String trustStorePassword;

    @Bean
    public RestTemplate mtlsRestTemplate() throws Exception {
        // 1. Load Client KeyStore from Stream (JAR-safe)
        KeyStore clientKeyStore = KeyStore.getInstance("PKCS12");
        try (InputStream is = keyStore.getInputStream()) {
            clientKeyStore.load(is, keyStorePassword.toCharArray());
        }

        // 2. Load TrustStore from Stream (JAR-safe)
        KeyStore trustKeyStore = KeyStore.getInstance("PKCS12");
        try (InputStream is = trustStore.getInputStream()) {
            trustKeyStore.load(is, trustStorePassword.toCharArray());
        }

        // 3. Build SSL Context using KeyStore OBJECTS (not file paths)
        SSLContext sslContext = SSLContextBuilder.create()
                .loadKeyMaterial(clientKeyStore, keyStorePassword.toCharArray())
                .loadTrustMaterial(trustKeyStore, null) // null = trust all in truststore
                .build();

        // 4. Configure HttpClient
        CloseableHttpClient httpClient = HttpClients.custom()
                .setConnectionManager(PoolingHttpClientConnectionManagerBuilder.create()
                        .setSSLSocketFactory(SSLConnectionSocketFactoryBuilder.create()
                                .setSslContext(sslContext)
                                .build())
                        .build())
                .build();

        return new RestTemplate(new HttpComponentsClientHttpRequestFactory(httpClient));
    }

    @Bean
    public KeyStore signingKeyStore() throws Exception {
        KeyStore ks = KeyStore.getInstance("PKCS12");
        // Also fix the signing bean to use InputStream
        try (InputStream is = keyStore.getInputStream()) {
            ks.load(is, keyStorePassword.toCharArray());
        }
        return ks;
    }
}
