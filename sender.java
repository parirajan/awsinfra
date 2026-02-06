package pvt.aotibank.payments.producer;

import com.ibm.mq.jms.MQConnectionFactory;
import com.ibm.msg.client.wmq.WMQConstants;
import javax.jms.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import jakarta.annotation.PostConstruct;
import java.util.concurrent.atomic.AtomicInteger; // [1] Import for Counter - PJ

@Component
public class MqSender {

    // [2] SHARED GLOBAL COUNTER - PJ
    // Defined here so all threads (mq1, mq2, mq3) share it.
    private final AtomicInteger globalSequence = new AtomicInteger(0);

    @Value("${ibm.mq.queue-manager}") private String qmgr;
    @Value("${ibm.mq.channel}") private String channel;
    @Value("${ibm.mq.conn-name}") private String connNames; 
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

        System.setProperty("com.ibm.mq.cfg.useIBMCipherMappings", "false");
        System.setProperty("com.ibm.ssl.performURLHostNameVerification", "false");
    }

    public void startAsync() {
        String[] nodes = connNames.split(",");
        for (String node : nodes) {
            final String targetNode = node.trim();
            if (targetNode.isEmpty()) continue;

            System.out.println("[INIT] Spawning producer thread for: " + targetNode);
            
            // Start the thread passing the specific node address
            new Thread(() -> runLoop(targetNode), "mq-producer-" + targetNode).start();
        }
    }

    private void runLoop(String nodeAddress) {
        int attempt = 0;
        
        // [3] NOTE: 'int i = 0' REMOVED from here to stop local counting - PJ
        
        while (true) {
            try {
                MQConnectionFactory f = new MQConnectionFactory();
                f.setTransportType(WMQConstants.WMQ_CM_CLIENT);
                f.setQueueManager(qmgr);
                f.setChannel(channel);
                f.setConnectionNameList(nodeAddress); // Connect only to this thread's node
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
                        // [4] Generate unique ID from the shared counter
                        int currentId = globalSequence.incrementAndGet();
                        
                        String payload = "PAYMENT-" + currentId + " via " + nodeAddress;
                        p.send(s.createTextMessage(payload));
                        
                        System.out.println("[PRODUCER] Sent: " + payload);
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
}
