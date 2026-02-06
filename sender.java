package pvt.aotibank.payments.producer;

import com.ibm.mq.jms.MQConnectionFactory;
import com.ibm.msg.client.wmq.WMQConstants;
import jakarta.annotation.PostConstruct;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.jms.*;
import java.io.FileInputStream;
import java.nio.charset.StandardCharsets;
import java.security.KeyStore;
import java.security.PrivateKey;
import java.security.Signature;
import java.util.Base64;
import java.util.concurrent.atomic.AtomicInteger;

@Component
public class MqSender {

    private final AtomicInteger globalSequence = new AtomicInteger(0);
    
    // Loaded at startup for signing
    private PrivateKey privateKey; 

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
    
    // The alias of YOUR certificate in the keystore (e.g., "mq-client" or "default")
    @Value("${ibm.mq.ssl.cert-alias:mq-client}") private String certAlias;

    @PostConstruct
    public void init() {
        // 1. Apply System Properties for mTLS
        System.setProperty("javax.net.ssl.keyStore", keyStorePath);
        System.setProperty("javax.net.ssl.keyStorePassword", keyStorePassword);
        System.setProperty("javax.net.ssl.keyStoreType", "PKCS12");
        System.setProperty("javax.net.ssl.trustStore", trustStorePath);
        System.setProperty("javax.net.ssl.trustStorePassword", trustStorePassword);
        System.setProperty("javax.net.ssl.trustStoreType", "PKCS12");
        System.setProperty("com.ibm.mq.cfg.useIBMCipherMappings", "false");
        System.setProperty("com.ibm.ssl.performURLHostNameVerification", "false");

        // 2. Load Private Key for Signing
        try {
            KeyStore ks = KeyStore.getInstance("PKCS12");
            try (FileInputStream fis = new FileInputStream(keyStorePath)) {
                ks.load(fis, keyStorePassword.toCharArray());
            }
            this.privateKey = (PrivateKey) ks.getKey(certAlias, keyStorePassword.toCharArray());
            if (this.privateKey == null) {
                System.err.println("[SECURITY ERROR] Could not find Private Key with alias: " + certAlias);
            } else {
                System.out.println("[SECURITY] Private Key loaded successfully for signing.");
            }
        } catch (Exception e) {
            System.err.println("[SECURITY CRITICAL] Failed to load signing key: " + e.getMessage());
        }
    }

    public void startAsync() {
        String[] nodes = connNames.split(",");
        for (String node : nodes) {
            final String targetNode = node.trim();
            if (targetNode.isEmpty()) continue;
            System.out.println("[INIT] Spawning producer thread for: " + targetNode);
            new Thread(() -> runLoop(targetNode), "mq-producer-" + targetNode).start();
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
                    MessageProducer p = s.createProducer(q);

                    System.out.println("[PRODUCER] Connected to node: " + nodeAddress);
                    attempt = 0;

                    while (true) {
                        int currentId = globalSequence.incrementAndGet();
                        String payload = "PAYMENT-" + currentId + " via " + nodeAddress;

                        // --- SIGNING STEP ---
                        String signature = generateSignature(payload);
                        
                        TextMessage msg = s.createTextMessage(payload);
                        // Attach signature as a custom header property
                        msg.setStringProperty("X-Message-Signature", signature);

                        p.send(msg);
                        System.out.println("[PRODUCER] Sent Signed Message: " + payload);
                        Thread.sleep(intervalMs);
                    }
                }
            } catch (Exception e) {
                attempt++;
                long backoff = Math.min(30000, 1000L * attempt);
                System.err.println("[PRODUCER Error] " + nodeAddress + " failed: " + e.getMessage());
                try { Thread.sleep(backoff); } catch (InterruptedException ignored) {}
            }
        }
    }

    // Helper: Generate SHA256withRSA Signature
    private String generateSignature(String data) throws Exception {
        Signature sig = Signature.getInstance("SHA256withRSA");
        sig.initSign(privateKey);
        sig.update(data.getBytes(StandardCharsets.UTF_8));
        return Base64.getEncoder().encodeToString(sig.sign());
    }
}
