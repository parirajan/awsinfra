package pvt.aotibank.payments.client.get;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import pvt.aotibank.payments.client.get.service.SseListener;
import org.springframework.context.ApplicationContext;

@SpringBootApplication
public class GetClientApplication {

    public static void main(String[] args) {
        ApplicationContext context = SpringApplication.run(GetClientApplication.class, args);
        
        // Start listening immediately
        context.getBean(SseListener.class).startListening();
    }
}
