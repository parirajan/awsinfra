package pvt.aotibank.payments.ingress.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.Resource;
import org.springframework.stereotype.Service;

import java.io.InputStream;
import java.security.KeyStore;
import java.security.PublicKey;
import java.security.Signature;
import java.security.cert.Certificate;
import java.util.Base64;

@Service
public class SignatureService {

    private final PublicKey clientPublicKey;

    public SignatureService(@Value("${server.ssl.trust-store}") Resource trustStore,
                            @Value("${server.ssl.trust-store-password}") String password) throws Exception {
        
        KeyStore ks = KeyStore.getInstance("PKCS12");
        // Use getInputStream() to support both classpath: and file: paths
        try (InputStream is = trustStore.getInputStream()) {
            ks.load(is, password.toCharArray());
        }

        Certificate cert = ks.getCertificate("client-public");
        if (cert == null) {
            throw new RuntimeException("Client Public Key 'client-public' not found in TrustStore");
        }
        this.clientPublicKey = cert.getPublicKey();
    }

    public boolean verify(String data, String signature) {
        try {
            Signature sig = Signature.getInstance("SHA256withRSA");
            sig.initVerify(clientPublicKey);
            sig.update(data.getBytes());
            return sig.verify(Base64.getDecoder().decode(signature));
        } catch (Exception e) {
            return false;
        }
    }
}
