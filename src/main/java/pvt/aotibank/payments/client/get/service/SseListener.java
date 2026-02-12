package pvt.aotibank.payments.client.get.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.http.codec.ServerSentEvent;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.core.publisher.Flux;

@Service
public class SseListener {

    private final WebClient webClient;

    @Value("${egress.url}")
    private String egressUrl;

    public SseListener(WebClient mtlsWebClient) {
        this.webClient = mtlsWebClient;
    }

    public void startListening() {
        System.out.println(">>> Connecting to Payment Stream at: " + egressUrl);

        ParameterizedTypeReference<ServerSentEvent<String>> type = 
            new ParameterizedTypeReference<>() {};

        Flux<ServerSentEvent<String>> eventStream = webClient.get()
                .uri(egressUrl)
                .retrieve()
                .bodyToFlux(type);

        eventStream.subscribe(
            // On Next
            event -> System.out.println(" [RECEIVED] " + event.data()),
            
            // On Error
            error -> {
                System.err.println(" [ERROR] Stream Disconnected: " + error.getMessage());
                // In a real app, you would add retry logic here
            },
            
            // On Complete
            () -> System.out.println(" [INFO] Stream Completed by Server")
        );
        
        // Block main thread to keep application alive for this demo
        try { Thread.currentThread().join(); } catch (InterruptedException e) {}
    }
}
