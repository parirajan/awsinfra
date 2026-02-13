cat << 'EOF' > put-client/src/main/java/pvt/aotibank/client/put/PutClientApplication.java
package pvt.aotibank.client.put;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.client.RestTemplate;
import pvt.aotibank.client.put.service.PayloadSigner;
import java.util.UUID;

record SecurePayload(String messageId, String data, String signature) {}

@SpringBootApplication
public class PutClientApplication implements CommandLineRunner {

    @Autowired private RestTemplate restTemplate;
    @Autowired private PayloadSigner signer;
    
    // Note: In the Unified Architecture, this points to the Gateway (Port 8443)
    @Value("${ingress.url}") private String url;

    public static void main(String[] args) {
        SpringApplication.run(PutClientApplication.class, args);
    }

    @Override
    public void run(String... args) {
        int i = 1;
        System.out.println(">>> Starting Put Client (Target: " + url + ")...");
        
        while(true) {
            try {
                // 1. Create Data
                String data = "{\"amount\": " + (100+i) + ", \"id\": \"PAY-" + i + "\"}";
                
                // 2. Sign Data
                String sig = signer.sign(data);
                
                // 3. Wrap in Payload
                SecurePayload payload = new SecurePayload(UUID.randomUUID().toString(), data, sig);
                
                System.out.println(">>> Sending Payment-" + i + "...");
                
                // 4. Send
                restTemplate.postForObject(url, payload, String.class);
                System.out.println(">>> SUCCESS");
                
                i++;
                Thread.sleep(3000); // Wait 3 seconds
            } catch (Exception e) {
                System.err.println(">>> FAILED: " + e.getMessage());
                try { Thread.sleep(5000); } catch (Exception ignored) {}
            }
        }
    }
}
EOF
