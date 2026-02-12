package pvt.aotibank.payments.client.put.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.security.KeyStore;
import java.security.PrivateKey;
import java.security.Signature;
import java.util.Base64;

@Service
public class PayloadSigner {

    private final PrivateKey privateKey;

    public PayloadSigner(KeyStore signingKeyStore, 
                         @Value("${client.ssl.key-store-password}") String password,
                         @Value("${client.ssl.key-alias}") String alias) throws Exception {
        // Load the Private Key directly for RSA Signing
        this.privateKey = (PrivateKey) signingKeyStore.getKey(alias, password.toCharArray());
        if (this.privateKey == null) {
            throw new RuntimeException("Could not find private key with alias: " + alias);
        }
    }

    public String sign(String data) throws Exception {
        Signature rsa = Signature.getInstance("SHA256withRSA");
        rsa.initSign(privateKey);
        rsa.update(data.getBytes());
        return Base64.getEncoder().encodeToString(rsa.sign());
    }
}
