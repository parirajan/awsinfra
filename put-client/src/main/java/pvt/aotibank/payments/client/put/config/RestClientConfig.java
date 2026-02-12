package pvt.aotibank.payments.client.put.config;

import org.apache.hc.client5.http.impl.classic.CloseableHttpClient;
import org.apache.hc.client5.http.impl.classic.HttpClients;
import org.apache.hc.client5.http.impl.io.PoolingHttpClientConnectionManagerBuilder;
import org.apache.hc.client5.http.io.HttpClientConnectionManager;
import org.apache.hc.client5.http.ssl.SSLConnectionSocketFactory;
import org.apache.hc.client5.http.ssl.SSLConnectionSocketFactoryBuilder;
import org.apache.hc.core5.ssl.SSLContextBuilder;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.io.Resource;
import org.springframework.http.client.HttpComponentsClientHttpRequestFactory;
import org.springframework.web.client.RestTemplate;

import javax.net.ssl.SSLContext;
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
        // 1. Load Keys and Trust Material
        SSLContext sslContext = SSLContextBuilder.create()
                .loadKeyMaterial(keyStore.getFile(), keyStorePassword.toCharArray(), keyStorePassword.toCharArray())
                .loadTrustMaterial(trustStore.getFile(), trustStorePassword.toCharArray())
                .build();

        // 2. Configure Apache HttpClient with SSL
        SSLConnectionSocketFactory sslSocketFactory = SSLConnectionSocketFactoryBuilder.create()
                .setSslContext(sslContext)
                .build();

        HttpClientConnectionManager cm = PoolingHttpClientConnectionManagerBuilder.create()
                .setSSLSocketFactory(sslSocketFactory)
                .build();

        CloseableHttpClient httpClient = HttpClients.custom()
                .setConnectionManager(cm)
                .build();

        // 3. Bind to RestTemplate
        return new RestTemplate(new HttpComponentsClientHttpRequestFactory(httpClient));
    }

    // Bean for the PayloadSigner to access the private key raw
    @Bean
    public KeyStore signingKeyStore() throws Exception {
        KeyStore ks = KeyStore.getInstance("PKCS12");
        ks.load(keyStore.getInputStream(), keyStorePassword.toCharArray());
        return ks;
    }
}
