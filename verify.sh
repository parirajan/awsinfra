#!/usr/bin/env bash
set -euo pipefail

QM="${QM:-SETTLE}"
PORT="${PORT:-1414}"
SSLDIR="${SSLDIR:-/var/mqm/qmgrs/${QM}/ssl}"
KDB="${KDB:-${SSLDIR}/key.kdb}"
STH="${STH:-${SSLDIR}/key.sth}"

CHANNEL="${CHANNEL:-${QM}.SVRCONN}"
LISTENER="${LISTENER:-${QM}.LISTENER}"

REQ_Q="${REQ_Q:-PAYMENT.REQUEST}"
RESP_Q="${RESP_Q:-PAYMENT.RESPONSE}"
DLQ="${DLQ:-PAYMENT.DLQ}"

U_WRITE="${U_WRITE:-mq_barter}"
U_READ="${U_READ:-mq_dispense}"

echo "=============================="
echo "Verify IBM MQ configuration"
echo "QM      : $QM"
echo "PORT    : $PORT"
echo "Listener: $LISTENER"
echo "Channel : $CHANNEL"
echo "SSLDir  : $SSLDIR"
echo "=============================="
echo

echo "[1] Queue manager status"
if /opt/mqm/bin/dspmq | grep -q "QMNAME(${QM})"; then
  /opt/mqm/bin/dspmq | grep "QMNAME(${QM})" || true
else
  echo "ERROR: QM ${QM} not found"
  exit 1
fi
echo

echo "[2] Listener + port check"
sudo ss -lntp | grep ":${PORT}" || echo "WARN: Nothing listening on port ${PORT} (listener may be down)"
echo

echo "[3] MQSC object checks"
MQSC_OUT="$(/opt/mqm/bin/runmqsc "${QM}" <<EOF
DISPLAY QMGR QMNAME CHLAUTH SSLKEYR CERTLABL DEADQ
DISPLAY LISTENER(${LISTENER}) ALL
DISPLAY CHANNEL(${CHANNEL}) CHLTYPE SSLCIPH SSLCAUTH MCAUSER
DISPLAY QLOCAL(${REQ_Q})  DEFPSIST
DISPLAY QLOCAL(${RESP_Q}) DEFPSIST
DISPLAY QLOCAL(${DLQ})    DEFPSIST
DISPLAY CHLAUTH(${CHANNEL})
DISPLAY AUTHREC PROFILE('${QM}') OBJTYPE(QMGR) PRINCIPAL('${U_WRITE}')
DISPLAY AUTHREC PROFILE('${QM}') OBJTYPE(QMGR) PRINCIPAL('${U_READ}')
DISPLAY AUTHREC PROFILE('${REQ_Q}')  OBJTYPE(QUEUE) PRINCIPAL('${U_WRITE}')
DISPLAY AUTHREC PROFILE('${RESP_Q}') OBJTYPE(QUEUE) PRINCIPAL('${U_WRITE}')
DISPLAY AUTHREC PROFILE('${REQ_Q}')  OBJTYPE(QUEUE) PRINCIPAL('${U_READ}')
DISPLAY AUTHREC PROFILE('${RESP_Q}') OBJTYPE(QUEUE) PRINCIPAL('${U_READ}')
END
EOF
)"
echo "$MQSC_OUT"
echo

echo "[4] TLS repository files"
if [[ -f "$KDB" ]]; then
  ls -l "$KDB"
else
  echo "ERROR: KDB not found: $KDB"
fi

if [[ -f "$STH" ]]; then
  ls -l "$STH"
else
  echo "WARN: Stash file not found: $STH (MQ needs stash unless you set KEYRPWD manually)"
fi
echo

echo "[5] Quick sanity expectations (non-fatal checks)"
echo " - Expect SSLCAUTH(REQUIRED) on channel"
echo " - Expect CHLAUTH(ENABLED) on QMGR"
echo " - Expect SSLKEYR points to ${SSLDIR}/key (no .kdb)"
echo

echo "[6] Tail MQ error log (last 60 lines)"
ERRLOG="/var/mqm/qmgrs/${QM}/errors/AMQERR01.LOG"
if [[ -f "$ERRLOG" ]]; then
  tail -n 60 "$ERRLOG"
else
  echo "WARN: No error log at $ERRLOG"
fi
echo

echo "[7] Optional: dspmqaut checks (if installed/available)"
if command -v /opt/mqm/bin/dspmqaut >/dev/null 2>&1; then
  echo "--- dspmqaut qmgr perms ---"
  /opt/mqm/bin/dspmqaut -m "$QM" -t qmgr -p "$U_WRITE"   || true
  /opt/mqm/bin/dspmqaut -m "$QM" -t qmgr -p "$U_READ"    || true
  echo "--- dspmqaut queue perms ($REQ_Q) ---"
  /opt/mqm/bin/dspmqaut -m "$QM" -t queue -n "$REQ_Q"  -p "$U_WRITE" || true
  /opt/mqm/bin/dspmqaut -m "$QM" -t queue -n "$REQ_Q"  -p "$U_READ"  || true
  echo "--- dspmqaut queue perms ($RESP_Q) ---"
  /opt/mqm/bin/dspmqaut -m "$QM" -t queue -n "$RESP_Q" -p "$U_WRITE" || true
  /opt/mqm/bin/dspmqaut -m "$QM" -t queue -n "$RESP_Q" -p "$U_READ"  || true
else
  echo "INFO: dspmqaut not found at /opt/mqm/bin/dspmqaut (skipping)"
fi
echo

echo "=============================="
echo "Verification script completed."
echo "If anything looks off, search AMQERR01.LOG and run:"
echo "  DISPLAY CHSTATUS(${CHANNEL}) SSLPEER"
echo "after a client connects to confirm DN matching."
echo "=============================="
