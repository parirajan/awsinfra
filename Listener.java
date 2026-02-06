package pvt.aotibank.payments.consumer;

import com.ibm.mq.jms.MQConnectionFactory;
import com.ibm.msg.client.wmq.WMQConstants;
import javax.jms.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import jakarta.annotation.PostConstruct;

@Component
public class MqListener {

    @Value("${ibm.mq.queue-manager}") private String qmgr;
    @Value("${ibm.mq.channel}") private String channel;
    @Value("${ibm.mq.conn-name}") private String connNames; // Reads "mq1(1414),mq2(1414),mq3(1414)"
    @Value("${ibm.mq.request-queue}") private String queueName;
    @Value("${ibm.mq.interval-ms:2000}") private long intervalMs;
    @Value("${ibm.mq.sslCipherSuite}") private String sslCipherSuite;

    @Value("${ibm.mq.ssl.keyStore}") private String keyStore;
    @Value("${ibm.mq.ssl.keyStorePassword}") private String keyStorePassword;
    @Value("${ibm.mq.ssl.trustStore}") private String trustStore;
    @Value("${ibm.mq.ssl.trustStorePassword}") private String trustStorePassword;

    @PostConstruct
    public void applySslProps() {
        // Core mTLS Keystore/Truststore setup
        System.setProperty("javax.net.ssl.keyStore", keyStore);
        System.setProperty("javax.net.ssl.keyStorePassword", keyStorePassword);
        System.setProperty("javax.net.ssl.keyStoreType", "PKCS12");
        System.setProperty("javax.net.ssl.trustStore", trustStore);
        System.setProperty("javax.net.ssl.trustStorePassword", trustStorePassword);
        System.setProperty("javax.net.ssl.trustStoreType", "PKCS12");

        // Disables hostname check to allow connection via LB/IP
        System.setProperty("com.ibm.mq.cfg.useIBMCipherMappings", "false");
        System.setProperty("com.ibm.ssl.performURLHostNameVerification", "false");
        
        System.out.println("[MQ SSL] Properties applied. Multi-node mTLS ready.");
    }

    public void startAsync() {
        // 1. Split the comma-separated list of nodes from your YAML
        String[] nodes = connNames.split(",");
        
        for (String node : nodes) {
            final String targetNode = node.trim();
            System.out.println("Starting dedicated listener thread for node: " + targetNode);
            
            // 2. Start a UNIQUE thread for EACH node to ensure simultaneous consumption
            Thread t = new Thread(() -> runLoop(targetNode), "mq-consumer-" + targetNode);
            t.setDaemon(false);
            t.start();
        }
    }

    private void runLoop(String nodeAddress) {
        int attempt = 0;
        while (true) {
            try {
                // 3. Create a dedicated factory for this specific node
                MQConnectionFactory f = new MQConnectionFactory();
                f.setTransportType(WMQConstants.WMQ_CM_CLIENT);
                f.setQueueManager(qmgr);
                f.setConnectionNameList(nodeAddress); 
                f.setChannel(channel);

                // --- TLS / mTLS setup ---
                f.setSSLCipherSuite(sslCipherSuite);
                // Disable MQCSP to rely strictly on certificate DN for authn
                f.setBooleanProperty(WMQConstants.USER_AUTHENTICATION_MQCSP, false);

                try (Connection c = f.createConnection()) {
                    c.start();
                    Session s = c.createSession(false, Session.AUTO_ACKNOWLEDGE);
                    Queue q = s.createQueue("queue:///" + queueName);
                    MessageConsumer consumer = s.createConsumer(q);

                    System.out.println("[CONSUMER] Connected to node: " + nodeAddress);
                    attempt = 0; // Reset backoff on success

                    while (true) {
                        Message m = consumer.receive(intervalMs);
                        if (m == null) continue;

                        if (m instanceof TextMessage tm) {
                            System.out.println("[CONSUMER] Received from " + nodeAddress + ": " + tm.getText());
                        } else {
                            System.out.println("[CONSUMER] Non-text message received from " + nodeAddress);
                        }
                    }
                }
            } catch (Exception e) {
                attempt++;
                // Exponential backoff to prevent flooding during node outages
                long backoffMs = Math.min(30000, 1000L * attempt);
                System.err.println("[CONSUMER Error] Node " + nodeAddress + " failed. Retrying in " + backoffMs + "ms: " + e.getMessage());
                try { Thread.sleep(backoffMs); } catch (InterruptedException ignored) {}
            }
        }
    }
}
