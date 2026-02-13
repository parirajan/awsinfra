package pvt.aotibank.client.get;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.reactive.function.client.WebClient;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.http.codec.ServerSentEvent;
import reactor.util.retry.Retry;
import java.time.Duration;

@SpringBootApplication
public class GetClientApplication implements CommandLineRunner {
    @Autowired private WebClient webClient;
    @Value("${egress.url}") private String url;

    public static void main(String[] args) { SpringApplication.run(GetClientApplication.class, args); }

    @Override
    public void run(String... args) {
        System.out.println(">>> Starting Payment Stream Listener...");
        
        connect();
        
        // Keep the app alive
        try { Thread.currentThread().join(); } catch (Exception e) {}
    }

    private void connect() {
        webClient.get()
                .uri(url)
                .retrieve()
                .bodyToFlux(new ParameterizedTypeReference<ServerSentEvent<String>>() {})
                // CRITICAL FIX: Retry indefinitely with 5-second backoff
                .retryWhen(Retry.fixedDelay(Long.MAX_VALUE, Duration.ofSeconds(5))
                        .doBeforeRetry(signal -> System.out.println(">>> Connection lost/failed. Retrying in 5s...")))
                .subscribe(
                        event -> System.out.println("[RECEIVED] " + event.data()),
                        error -> System.err.println(">>> Fatal Error: " + error.getMessage()) // Should rarely happen with retry
                );
    }
}
