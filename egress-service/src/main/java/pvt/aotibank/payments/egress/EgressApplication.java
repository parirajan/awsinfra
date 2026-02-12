package pvt.aotibank.payments.egress;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.jms.annotation.EnableJms;

@SpringBootApplication
@EnableJms
public class EgressApplication {
    public static void main(String[] args) {
        SpringApplication.run(EgressApplication.class, args);
    }
}
