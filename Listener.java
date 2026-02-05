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
    @Value("${ibm.mq.conn-name}") private String connNames; // Reads the comma list
    @Value("${ibm.mq.request-queue}") private String queueName;
    @Value("${ibm.mq.interval-ms:2000}") private long intervalMs;
    @Value("${ibm.mq.sslCipherSuite}") private String sslCipherSuite;

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

        // Required to bypass hostname verification and use standard JSSE
        System.setProperty("com.ibm.mq.cfg.useIBMCipherMappings", "false");
        System.setProperty("com.ibm.ssl.performURLHostNameVerification", "false");
    }

    public void startAsync() {
        // Split the connection list into individual nodes
        String[] nodes = connNames.split(",");
        for (String node : nodes) {
            String targetNode = node.trim();
            System.out.println("Starting dedicated thread for node: " + targetNode);
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
                f.setConnectionNameList(nodeAddress); // Connect to only ONE specific node
                f.setChannel(channel);

                // mTLS Setup
                f.setSSLCipherSuite(sslCipherSuite);
                f.setBooleanProperty(WMQConstants.USER_AUTHENTICATION_MQCSP, false);

                try (Connection c = f.createConnection()) {
                    c.start();
                    Session s = c.createSession(false, Session.AUTO_ACKNOWLEDGE);
                    Queue q = s.createQueue("queue:///" + queueName);
                    MessageConsumer consumer = s.createConsumer(q);

                    System.out.println("[CONSUMER] Connected to node: " + nodeAddress);
                    attempt = 0; // Reset attempts on successful connection

                    while (true) {
                        Message m = consumer.receive(intervalMs);
                        if (m instanceof TextMessage tm) {
                            System.out.println("[CONSUMER] Received from " + nodeAddress + ": " + tm.getText());
                        }
                    }
                }
            } catch (Exception e) {
                attempt++;
                long backoff = Math.min(30000, 1000L * attempt);
                System.err.println("[CONSUMER Error] Node " + nodeAddress + " failed: " + e.getMessage());
                try { Thread.sleep(backoff); } catch (InterruptedException ignored) {}
            }
        }
    }
}
