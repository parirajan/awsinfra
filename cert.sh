#!/bin/bash
mkdir -p certs
cd certs

echo ">>> Generating Certificates..."

# 1. Create a Self-Signed Certificate Authority (CA)
# This CA will sign both the Server and Client certificates.
openssl req -x509 -sha256 -days 3650 -newkey rsa:4096 -keyout ca.key -out ca.crt -nodes -subj "/CN=AotiBankRootCA"

# 2. Generate Server Certificate (Ingress & Egress)
# Create a Key & CSR for the Server
openssl req -new -newkey rsa:4096 -keyout server.key -out server.csr -nodes -subj "/CN=server"
# Sign the Server CSR with the CA
openssl x509 -req -CA ca.crt -CAkey ca.key -in server.csr -out server.crt -days 365 -CAcreateserial
# Package Server Identity into PKCS12 (Keystore for the Server)
openssl pkcs12 -export -out server-keystore.p12 -inkey server.key -in server.crt -certfile ca.crt -passout pass:changeit

# 3. Generate Client Certificate (Put & Get Clients)
# Create a Key & CSR for the Client
openssl req -new -newkey rsa:4096 -keyout client.key -out client.csr -nodes -subj "/CN=client"
# Sign the Client CSR with the CA
openssl x509 -req -CA ca.crt -CAkey ca.key -in client.csr -out client.crt -days 365
# Package Client Identity into PKCS12 (Keystore for the Client)
openssl pkcs12 -export -out client-keystore.p12 -inkey client.key -in client.crt -certfile ca.crt -passout pass:password

# 4. Create Truststore (Contains CA Public Key)
# Java needs this to trust any cert signed by AotiBankRootCA
keytool -import -trustcacerts -noprompt -alias ca -file ca.crt -keystore truststore.p12 -storepass changeit -storetype PKCS12

# 5. Import Client Public Key into Truststore
# This allows the Server application to load the specific Client Public Key by alias "client-public" for signature verification
keytool -import -noprompt -alias client-public -file client.crt -keystore truststore.p12 -storepass changeit -storetype PKCS12

echo ">>> Certificates generated in /certs folder."
ls -l *.p12
