#!/usr/bin/env bash
set -euo pipefail

# --- Configuration Variables ---
OUT=${OUT:-./out}
QM_NAMES=${QM_NAMES:-"FNQM1 FNQM2 FNQM3"}
CLIENT_CNS=${CLIENT_CNS:-"MQ-PRODUCER MQ-CONSUMER"}

CA_KEY_BITS=${CA_KEY_BITS:-8192}
QM_KEY_BITS=${QM_KEY_BITS:-8192}
CLIENT_KEY_BITS=${CLIENT_KEY_BITS:-8192}

ORG=${ORG:-"AOTIBANK"}
OU=${OU:-"PAYMENTS"}
COUNTRY=${COUNTRY:-"US"}
QM_OU=${QM_OU:-"PAYMENTS"}
CLIENT_OU=${CLIENT_OU:-"PAYMENTS"}

CA_SUBJ="/C=${COUNTRY}/O=${ORG}/OU=${OU}/CN=*.${OU}.${ORG}.PVT"

P12_PASS=${P12_PASS:-changeit}
TRUST_PASS=${TRUST_PASS:-changeit}

# --- Cleanup & Setup ---
echo ">>> Cleaning up old certificates..."
rm -rf "$OUT"
mkdir -p "$OUT/ca" "$OUT/trust" "$OUT/qmgr" "$OUT/client"

# =================================================================
# 1. Generate Certificate Authority (CA)
# =================================================================
echo ">>> Generating CA (${CA_KEY_BITS}-bit)..."
openssl genrsa -out "$OUT/ca/ca.key" "$CA_KEY_BITS"
openssl req -x509 -new -key "$OUT/ca/ca.key" -sha256 -days 3650 \
  -subj "$CA_SUBJ" -out "$OUT/ca/ca.crt"

# Create the initial Truststore containing just the CA
echo ">>> Creating initial Java Truststore with CA..."
if command -v keytool >/dev/null 2>&1; then
  keytool -importcert -noprompt \
    -alias local-ca \
    -file "$OUT/ca/ca.crt" \
    -keystore "$OUT/trust/trust.p12" \
    -storetype PKCS12 \
    -storepass "$TRUST_PASS"
  echo ">>> Initial Truststore created at $OUT/trust/trust.p12"
else
  echo ">>> ERROR: keytool not found! Java is required."
  exit 1
fi

# =================================================================
# 2. Generate Server Certificates (Queue Managers)
# =================================================================
for QM in $QM_NAMES; do
  QM_DIR="$OUT/qmgr/$QM"
  mkdir -p "$QM_DIR"
  echo ">>> Generating server key/cert for $QM..."

  # Generate Key & CSR
  openssl genrsa -out "$QM_DIR/qmgr.key" "$QM_KEY_BITS"
  openssl req -new -key "$QM_DIR/qmgr.key" \
    -subj "/C=$COUNTRY/O=$ORG/OU=$QM_OU/CN=$QM" \
    -out "$QM_DIR/qmgr.csr"

  # Sign with CA
  openssl x509 -req -in "$QM_DIR/qmgr.csr" \
    -CA "$OUT/ca/ca.crt" -CAkey "$OUT/ca/ca.key" \
    -CAcreateserial -out "$QM_DIR/qmgr.crt" -days 1825 -sha256

  # Create PKCS12 for QM (Label is usually lowercase qmgr name or 'ibmwebspheremq<qmname_lowercase>')
  LABEL="ibmwebspheremq$(echo $QM | tr '[:upper:]' '[:lower:]')"
  
  openssl pkcs12 -export \
    -inkey "$QM_DIR/qmgr.key" \
    -in "$QM_DIR/qmgr.crt" \
    -certfile "$OUT/ca/ca.crt" \
    -name "$LABEL" \
    -out "$QM_DIR/qmgr.p12" \
    -password "pass:$P12_PASS"
    
  echo ">>> $QM: PKCS12 ready -> $QM_DIR/qmgr.p12 (label=$LABEL)"
done

# =================================================================
# 3. Generate Client Certificates & Update Unified Truststore
# =================================================================
for CN in $CLIENT_CNS; do
  C_DIR="$OUT/client/$CN"
  mkdir -p "$C_DIR"
  echo ">>> Generating client key/cert CN=$CN..."

  # Generate Key & CSR
  openssl genrsa -out "$C_DIR/client.key" "$CLIENT_KEY_BITS"
  openssl req -new -key "$C_DIR/client.key" \
    -subj "/C=$COUNTRY/O=$ORG/OU=$CLIENT_OU/CN=$CN" \
    -out "$C_DIR/client.csr"

  # Sign with CA
  openssl x509 -req -in "$C_DIR/client.csr" \
    -CA "$OUT/ca/ca.crt" -CAkey "$OUT/ca/ca.key" \
    -CAcreateserial -out "$C_DIR/client.crt" -days 1825 -sha256

  # Generate Alias: Force lowercase to match Spring Boot config (e.g., client-cert-mq-producer)
  ALIAS_LOWER="client-cert-$(echo $CN | tr '[:upper:]' '[:lower:]')"

  # Create Client Keystore (client.p12)
  openssl pkcs12 -export \
    -inkey "$C_DIR/client.key" \
    -in "$C_DIR/client.crt" \
    -certfile "$OUT/ca/ca.crt" \
    -name "$ALIAS_LOWER" \
    -out "$C_DIR/client.p12" \
    -password "pass:$P12_PASS"

  # --- CRITICAL STEP: Import into Unified Truststore ---
  echo ">>> Importing $CN public cert into Unified Truststore as '$ALIAS_LOWER'..."
  keytool -importcert -noprompt \
    -alias "$ALIAS_LOWER" \
    -file "$C_DIR/client.crt" \
    -keystore "$OUT/trust/trust.p12" \
    -storepass "$TRUST_PASS"
done

# =================================================================
# 4. Distribute Unified Truststore to All Clients
# =================================================================
# Now that trust.p12 contains CA + Producer + Consumer, give it to everyone.
for CN in $CLIENT_CNS; do
  C_DIR="$OUT/client/$CN"
  echo ">>> Copying final Unified Truststore to $CN..."
  cp "$OUT/trust/trust.p12" "$C_DIR/trust.p12"
done

# =================================================================
# 5. Finalize
# =================================================================
echo ">>> Setting permissions..."
chmod -R 755 "$OUT"
# Attempt to change ownership if running as root, ignore if fails
chown -R 1001:0 "$OUT" || true
touch "$OUT/.done"

echo "==========================================================="
echo "SUCCESS! Certificates generated in $OUT"
echo "Unified Truststore ($OUT/trust/trust.p12) contains:"
keytool -list -keystore "$OUT/trust/trust.p12" -storepass "$TRUST_PASS" | grep "Alias name"
echo "==========================================================="
