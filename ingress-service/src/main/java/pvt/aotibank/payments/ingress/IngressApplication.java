package pvt.aotibank.payments.ingress;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.jms.annotation.EnableJms;

@SpringBootApplication
@EnableJms
public class IngressApplication {
    public static void main(String[] args) {
        SpringApplication.run(IngressApplication.class, args);
    }
}
