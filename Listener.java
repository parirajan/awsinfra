package pvt.aotibank.payments.consumer;

import com.ibm.mq.jms.MQConnectionFactory;
import com.ibm.msg.client.wmq.WMQConstants;
import jakarta.annotation.PostConstruct;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.jms.*;
import java.io.FileInputStream;
import java.nio.charset.StandardCharsets;
import java.security.KeyStore;
import java.security.PublicKey;
import java.security.Signature;
import java.security.cert.Certificate;
import java.util.Base64;

@Component
public class MqListener {

    // Loaded at startup for verification
    private PublicKey senderPublicKey;

    @Value("${ibm.mq.queue-manager}") private String qmgr;
    @Value("${ibm.mq.channel}") private String channel;
    @Value("${ibm.mq.conn-name}") private String connNames;
    @Value("${ibm.mq.request-queue}") private String queueName;
    @Value("${ibm.mq.interval-ms:2000}") private long intervalMs;
    @Value("${ibm.mq.sslCipherSuite:TLS_AES_256_GCM_SHA384}") private String sslCipherSuite;

    // SSL & Key Config
    @Value("${ibm.mq.ssl.keyStore}") private String keyStorePath;
    @Value("${ibm.mq.ssl.keyStorePassword}") private String keyStorePassword;
    @Value("${ibm.mq.ssl.trustStore}") private String trustStorePath;
    @Value("${ibm.mq.ssl.trustStorePassword}") private String trustStorePassword;

    // The alias of the SENDER'S cert in your truststore
    @Value("${ibm.mq.ssl.cert-alias:mq-client}") private String senderCertAlias;

    @PostConstruct
    public void init() {
        System.setProperty("javax.net.ssl.keyStore", keyStorePath);
        System.setProperty("javax.net.ssl.keyStorePassword", keyStorePassword);
        System.setProperty("javax.net.ssl.keyStoreType", "PKCS12");
        System.setProperty("javax.net.ssl.trustStore", trustStorePath);
        System.setProperty("javax.net.ssl.trustStorePassword", trustStorePassword);
        System.setProperty("javax.net.ssl.trustStoreType", "PKCS12");
        System.setProperty("com.ibm.mq.cfg.useIBMCipherMappings", "false");
        System.setProperty("com.ibm.ssl.performURLHostNameVerification", "false");

        // 2. Load Public Key for Verification
        try {
            KeyStore ks = KeyStore.getInstance("PKCS12");
            // NOTE: In mTLS, we verify using the TRUSTSTORE (where the sender's public cert lives)
            try (FileInputStream fis = new FileInputStream(trustStorePath)) {
                ks.load(fis, trustStorePassword.toCharArray());
            }
            Certificate cert = ks.getCertificate(senderCertAlias);
            if (cert != null) {
                this.senderPublicKey = cert.getPublicKey();
                System.out.println("[SECURITY] Sender Public Key loaded successfully.");
            } else {
                System.err.println("[SECURITY ERROR] Sender Cert not found in TrustStore with alias: " + senderCertAlias);
            }
        } catch (Exception e) {
            System.err.println("[SECURITY CRITICAL] Failed to load validation key: " + e.getMessage());
        }
    }

    public void startAsync() {
        String[] nodes = connNames.split(",");
        for (String node : nodes) {
            final String targetNode = node.trim();
            if (targetNode.isEmpty()) continue;
            System.out.println("[INIT] Spawning listener thread for: " + targetNode);
            new Thread(() -> runLoop(targetNode), "mq-consumer-" + targetNode).start();
        }
    }

    private void runLoop(String nodeAddress) {
        int attempt = 0;
        while (true) {
            try {
                MQConnectionFactory f = new MQConnectionFactory();
                f.setTransportType(WMQConstants.WMQ_CM_CLIENT);
                f.setQueueManager(qmgr);
                f.setChannel(channel);
                f.setConnectionNameList(nodeAddress);
                f.setSSLCipherSuite(sslCipherSuite);
                f.setBooleanProperty(WMQConstants.USER_AUTHENTICATION_MQCSP, false);

                try (Connection c = f.createConnection()) {
                    c.start();
                    Session s = c.createSession(false, Session.AUTO_ACKNOWLEDGE);
                    Queue q = s.createQueue("queue:///" + queueName);
                    MessageConsumer consumer = s.createConsumer(q);

                    System.out.println("[CONSUMER] Connected to node: " + nodeAddress);
                    attempt = 0;

                    while (true) {
                        Message m = consumer.receive(intervalMs);
                        if (m instanceof TextMessage tm) {
                            String payload = tm.getText();
                            String signature = tm.getStringProperty("X-Message-Signature");

                            // --- VERIFICATION STEP ---
                            if (isValidSignature(payload, signature)) {
                                System.out.println("[VERIFIED-OK] Processing: " + payload);
                            } else {
                                System.err.println("[SECURITY ALERT] Signature Invalid! Discarding: " + payload);
                                // Logic to send to Dead Letter Queue (DLQ) could go here
                            }
                        }
                    }
                }
            } catch (Exception e) {
                attempt++;
                long backoff = Math.min(30000, 1000L * attempt);
                System.err.println("[CONSUMER Error] " + nodeAddress + " failed: " + e.getMessage());
                try { Thread.sleep(backoff); } catch (InterruptedException ignored) {}
            }
        }
    }

    // Helper: Verify SHA256withRSA Signature
    private boolean isValidSignature(String data, String signatureStr) {
        if (senderPublicKey == null || signatureStr == null) return false;
        try {
            Signature sig = Signature.getInstance("SHA256withRSA");
            sig.initVerify(senderPublicKey);
            sig.update(data.getBytes(StandardCharsets.UTF_8));
            byte[] signatureBytes = Base64.getDecoder().decode(signatureStr);
            return sig.verify(signatureBytes);
        } catch (Exception e) {
            System.err.println("Verification Check Failed: " + e.getMessage());
            return false;
        }
    }
}
