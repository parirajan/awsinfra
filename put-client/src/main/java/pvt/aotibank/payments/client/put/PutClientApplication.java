package pvt.aotibank.payments.client.put;

import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;
import pvt.aotibank.payments.client.put.service.PaymentSender;

@SpringBootApplication
public class PutClientApplication {

    public static void main(String[] args) {
        SpringApplication.run(PutClientApplication.class, args);
    }

    @Bean
    CommandLineRunner run(PaymentSender sender) {
        return args -> {
            int counter = 1;
            
            // Infinite loop to keep sending payments
            while (true) {
                try {
                    String paymentId = "Payment-" + counter;
                    String json = "{\"amount\": " + (100 + counter) + ", \"currency\": \"USD\", \"account\": \"" + paymentId + "\"}";
                    
                    System.out.println(">>> Sending " + paymentId + "...");
                    sender.send(json);
                    
                    System.out.println(">>> SUCCESS! " + paymentId + " Sent.");
                    
                    counter++; 
                    Thread.sleep(3000); // Wait 3 seconds before next payment
                    
                } catch (Exception e) {
                    System.err.println(">>> Connection Failed: " + e.getMessage());
                    System.out.println(">>> Retrying in 5 seconds...");
                    try { Thread.sleep(5000); } catch (InterruptedException ignored) {}
                }
            }
        };
    }
}
