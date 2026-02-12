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

    // Trigger sending a test payment on startup
    @Bean
    CommandLineRunner run(PaymentSender sender) {
        return args -> {
            System.out.println(">>> Sending Payment 1...");
            sender.sendPayment("{\"amount\": 5000, \"currency\": \"USD\", \"account\": \"123456\"}");
            
            System.out.println(">>> Sending Payment 2...");
            sender.sendPayment("{\"amount\": 150, \"currency\": \"EUR\", \"account\": \"987654\"}");
        };
    }
}
