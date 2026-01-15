#!/usr/bin/env bash
set -euo pipefail

DOMAINS=(
  "settle.anchorbank.com"
  "barter.anchorbank.com"
  "haggle.anchorbank.com"
)

# b and c:
JKS_DOMAINS=(
  "barter.anchorbank.com"
  "haggle.anchorbank.com"
)

OUT_DIR="${OUT_DIR:-./tls_out}"
DAYS_VALID="${DAYS_VALID:-825}"
KEY_SIZE="${KEY_SIZE:-2048}"

P12_PASS="${P12_PASS:-changeit}"
JKS_PASS="${JKS_PASS:-changeit}"

SUBJ_O="${SUBJ_O:-AnchorBank}"
SUBJ_OU="${SUBJ_OU:-Engineering}"
SUBJ_C="${SUBJ_C:-US}"
SUBJ_ST="${SUBJ_ST:-CA}"
SUBJ_L="${SUBJ_L:-Irvine}"

mkdir -p "$OUT_DIR"

need_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "ERROR: missing $1" >&2; exit 1; }; }
need_cmd openssl
need_cmd keytool

make_cert() {
  local host="$1"
  local base="${OUT_DIR}/${host}"

  echo "==> Generating PEM cert+key for: ${host}"

  openssl req -x509 -newkey "rsa:${KEY_SIZE}" -nodes \
    -keyout "${base}.key.pem" \
    -out "${base}.crt.pem" \
    -sha256 -days "${DAYS_VALID}" \
    -subj "/C=${SUBJ_C}/ST=${SUBJ_ST}/L=${SUBJ_L}/O=${SUBJ_O}/OU=${SUBJ_OU}/CN=${host}" \
    -addext "subjectAltName=DNS:${host}" \
    -addext "keyUsage=digitalSignature,keyEncipherment" \
    -addext "extendedKeyUsage=serverAuth,clientAuth"

  # PEM bundles (handy for apps)
  cat "${base}.crt.pem" "${base}.key.pem" > "${base}.bundle.pem"

  echo "    Wrote PEM:"
  echo "      ${base}.crt.pem"
  echo "      ${base}.key.pem"
  echo "      ${base}.bundle.pem"
}

make_jks() {
  local host="$1"
  local base="${OUT_DIR}/${host}"
  local alias="${host//./-}"

  echo "==> Creating JKS for: ${host}"

  # PKCS12 containing private key + cert
  openssl pkcs12 -export \
    -in "${base}.crt.pem" \
    -inkey "${base}.key.pem" \
    -name "${alias}" \
    -out "${base}.p12" \
    -passout "pass:${P12_PASS}"

  # PKCS12 -> JKS
  keytool -importkeystore \
    -srckeystore "${base}.p12" -srcstoretype PKCS12 -srcstorepass "${P12_PASS}" \
    -destkeystore "${base}.jks" -deststoretype JKS -deststorepass "${JKS_PASS}" \
    -alias "${alias}" \
    -noprompt >/dev/null

  echo "    Wrote JKS:"
  echo "      ${base}.p12"
  echo "      ${base}.jks"
}

echo "Output directory: ${OUT_DIR}"
echo

# 1) Always create PEM for all domains
for d in "${DOMAINS[@]}"; do
  make_cert "$d"
done

echo
# 2) Create JKS for b & c (which already have PEM)
for d in "${JKS_DOMAINS[@]}"; do
  make_jks "$d"
done

echo
echo "Done."
