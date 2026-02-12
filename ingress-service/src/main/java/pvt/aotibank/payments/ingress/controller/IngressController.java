package pvt.aotibank.payments.ingress.controller;

import pvt.aotibank.payments.ingress.model.SecurePayload;
import pvt.aotibank.payments.ingress.service.SignatureService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.jms.core.JmsTemplate;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/v1/payments")
public class IngressController {

    @Autowired
    private JmsTemplate jmsTemplate;

    @Autowired
    private SignatureService signatureService;

    @Value("${ibm.mq.queue}")
    private String queueName;

    @PostMapping("/ingress")
    public ResponseEntity<String> acceptPayment(@RequestBody SecurePayload payload) {
        // 1. Verify RSA Signature
        if (!signatureService.verify(payload.data(), payload.signature())) {
            return ResponseEntity.status(401).body("Invalid Signature");
        }

        // 2. Push to IBM MQ
        jmsTemplate.convertAndSend(queueName, payload.data());

        return ResponseEntity.accepted().body("Payment Queued");
    }
}
