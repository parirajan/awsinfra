package pvt.aotibank.payments.client.put.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

@Service
public class PaymentSender {

    private final RestTemplate restTemplate;
    private final PayloadSigner signer;
    
    @Value("${ingress.url}")
    private String ingressUrl;

    public PaymentSender(RestTemplate mtlsRestTemplate, PayloadSigner signer) {
        this.restTemplate = mtlsRestTemplate;
        this.signer = signer;
    }

    public void sendPayment(String rawJson) {
        try {
            // 1. Sign
            String signature = signer.sign(rawJson);
            
            // 2. Wrap
            SecurePayload payload = new SecurePayload(rawJson, signature);

            // 3. Send
            String response = restTemplate.postForObject(ingressUrl, payload, String.class);
            System.out.println(" [SUCCESS] Ingress Response: " + response);
            
        } catch (Exception e) {
            System.err.println(" [ERROR] Failed to send payment: " + e.getMessage());
            e.printStackTrace();
        }
    }
    
    // Inner DTO
    record SecurePayload(String data, String signature) {}
}
