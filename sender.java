package pvt.aotibank.payments.producer;

import com.ibm.mq.jms.MQConnectionFactory;
import com.ibm.msg.client.wmq.WMQConstants;
import javax.jms.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import jakarta.annotation.PostConstruct;

@Component
public class MqSender {

    @Value("${ibm.mq.queue-manager}") private String qmgr;
    @Value("${ibm.mq.channel}") private String channel;
    @Value("${ibm.mq.conn-name}") private String connNames; // Expects "mq1(1414),mq2(1414),mq3(1414)"
    @Value("${ibm.mq.request-queue}") private String queueName;
    @Value("${ibm.mq.interval-ms:2000}") private long intervalMs;
    @Value("${ibm.mq.sslCipherSuite:TLS_AES_256_GCM_SHA384}") private String sslCipherSuite;

    @Value("${ibm.mq.ssl.keyStore}") private String keyStore;
    @Value("${ibm.mq.ssl.keyStorePassword}") private String keyStorePassword;
    @Value("${ibm.mq.ssl.trustStore}") private String trustStore;
    @Value("${ibm.mq.ssl.trustStorePassword}") private String trustStorePassword;

    @PostConstruct
    public void applySslProps() {
        System.setProperty("javax.net.ssl.keyStore", keyStore);
        System.setProperty("javax.net.ssl.keyStorePassword", keyStorePassword);
        System.setProperty("javax.net.ssl.keyStoreType", "PKCS12");
        System.setProperty("javax.net.ssl.trustStore", trustStore);
        System.setProperty("javax.net.ssl.trustStorePassword", trustStorePassword);
        System.setProperty("javax.net.ssl.trustStoreType", "PKCS12");

        // Required to bypass hostname verification for mTLS via LB/IP
        System.setProperty("com.ibm.mq.cfg.useIBMCipherMappings", "false");
        System.setProperty("com.ibm.ssl.performURLHostNameVerification", "false");
    }

    public void startAsync() {
        // Parse the comma-separated list into individual nodes
        String[] nodes = connNames.split(",");
        for (String node : nodes) {
            String targetNode = node.trim();
            System.out.println("Starting dedicated producer thread for node: " + targetNode);
            
            // Spawn a unique thread for each QM to ensure parallel delivery
            new Thread(() -> runLoop(targetNode), "mq-producer-" + targetNode).start();
        }
    }

    private void runLoop(String nodeAddress) {
        int attempt = 0;
        int i = 0;
        while (true) {
            try {
                MQConnectionFactory f = new MQConnectionFactory();
                f.setTransportType(WMQConstants.WMQ_CM_CLIENT);
                f.setQueueManager(qmgr);
                f.setConnectionNameList(nodeAddress); // Target one specific node
                f.setChannel(channel);

                // mTLS Setup
                f.setSSLCipherSuite(sslCipherSuite);
                f.setBooleanProperty(WMQConstants.USER_AUTHENTICATION_MQCSP, false);

                try (Connection c = f.createConnection()) {
                    c.start();
                    Session s = c.createSession(false, Session.AUTO_ACKNOWLEDGE);
                    Queue q = s.createQueue("queue:///" + queueName);
                    MessageProducer p = s.createProducer(q);

                    System.out.println("[PRODUCER] Connected to node: " + nodeAddress);
                    attempt = 0; // Reset backoff on success

                    while (true) {
                        TextMessage m = s.createTextMessage("PAYMENT-" + (++i) + " via " + nodeAddress);
                        p.send(m);
                        System.out.println("[PRODUCER] Sent: " + m.getText());
                        Thread.sleep(intervalMs);
                    }
                }
            } catch (Exception e) {
                attempt++;
                long backoff = Math.min(30000, 1000L * attempt);
                System.err.println("[PRODUCER Error] Node " + nodeAddress + " failed: " + e.getMessage());
                try { Thread.sleep(backoff); } catch (InterruptedException ignored) {}
            }
        }
    }
}
