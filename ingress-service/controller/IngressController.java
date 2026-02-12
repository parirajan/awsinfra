package pvt.aotibank.payments.ingress.controller;

import pvt.aotibank.payments.ingress.model.SecurePayload;
import pvt.aotibank.payments.ingress.service.SignatureService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jms.core.JmsTemplate;
import org.springframework.web.bind.annotation.*;
import org.springframework.http.ResponseEntity;

@RestController
@RequestMapping("/v1/payments")
public class IngressController {

    @Autowired
    private JmsTemplate jmsTemplate;

    @Autowired
    private SignatureService signatureService;

    @PostMapping("/ingress")
    public ResponseEntity<String> processPayment(@RequestBody SecurePayload payload) throws Exception {
        // 1. Verify Payload Signature (Non-repudiation)
        if (!signatureService.verify(payload.data(), payload.signature())) {
            return ResponseEntity.status(401).body("Signature Verification Failed");
        }

        // 2. Publish to IBM MQ
        jmsTemplate.convertAndSend("PAYMENT.QUEUE.IN", payload.data());
        
        return ResponseEntity.accepted().body("Payment queued for processing: " + payload.messageId());
    }
}
