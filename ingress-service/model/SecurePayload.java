package pvt.aotibank.payments.ingress.model;

public record SecurePayload(String messageId, String data, String signature) {}
