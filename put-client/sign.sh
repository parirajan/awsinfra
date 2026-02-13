cat << 'EOF' > put-client/src/main/java/pvt/aotibank/client/put/service/PayloadSigner.java
package pvt.aotibank.client.put.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import java.security.*;
import java.util.Base64;
import java.security.KeyStore;

@Service
public class PayloadSigner {
    private final PrivateKey privateKey;

    public PayloadSigner(KeyStore signingKeyStore, 
                         @Value("${client.ssl.key-alias}") String alias) throws Exception {
        // Loads the private key from the keystore to sign the payload
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
