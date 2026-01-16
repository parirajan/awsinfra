#!/usr/bin/env bash
set -euo pipefail

QM=SETTLE
PORT=1414
SSLKEYR="/var/mqm/qmgrs/${QM}/ssl/key"   # no .kdb

# Create QM if not exists
if /opt/mqm/bin/dspmq | grep -q "QMNAME(${QM})"; then
  echo "QM ${QM} already exists - skipping crtmqm"
else
  /opt/mqm/bin/crtmqm -q -u PAYMENT.DLQ "${QM}"
fi

/opt/mqm/bin/strmqm "${QM}" || true

# Ensure OS users exist (do not add to mqm group)
id -u mq_barter   >/dev/null 2>&1 || useradd -r -m mq_barter
id -u mq_dispense >/dev/null 2>&1 || useradd -r -m mq_dispense

# Run MQSC config
/opt/mqm/bin/runmqsc "${QM}" <<'EOF'
* =========================
*  SETTLE - Single node mTLS
* =========================

* --- TLS key repository (KDB). Must exist with .kdb + .sth ---
ALTER QMGR SSLKEYR('/var/mqm/qmgrs/SETTLE/ssl/key')

* If your personal cert label is NOT the default, set it:
* ALTER QMGR CERTLABL('ibmwebspheremqsettle')

REFRESH SECURITY TYPE(SSL)

* --- Listener ---
DEFINE LISTENER(SETTLE.LISTENER) TRPTYPE(TCP) CONTROL(QMGR) PORT(1414) REPLACE
START LISTENER(SETTLE.LISTENER)

* --- Queues ---
DEFINE QLOCAL(PAYMENT.REQUEST)  DEFPSIST(YES) REPLACE
DEFINE QLOCAL(PAYMENT.RESPONSE) DEFPSIST(YES) REPLACE
DEFINE QLOCAL(PAYMENT.DLQ)      DEFPSIST(YES) REPLACE
ALTER QMGR DEADQ(PAYMENT.DLQ)

* --- SVRCONN channel with mTLS ---
DEFINE CHANNEL(SETTLE.SVRCONN) CHLTYPE(SVRCONN) TRPTYPE(TCP) +
  SSLCAUTH(REQUIRED) +
  SSLCIPH('TLS_AES_256_GCM_SHA384') +
  MCAUSER('nobody') REPLACE

* --- Enable channel authentication rules ---
ALTER QMGR CHLAUTH(ENABLED)

* --- Map client cert CNs -> MCAUSER (use wildcard to avoid DN ordering differences) ---
SET CHLAUTH(SETTLE.SVRCONN) TYPE(SSLPEERMAP) +
  SSLPEER('CN=BARTER.PAYMENTS.ANCHORBANK.PVT*') +
  USERSRC(MAP) MCAUSER('mq_barter') ACTION(REPLACE)

SET CHLAUTH(SETTLE.SVRCONN) TYPE(SSLPEERMAP) +
  SSLPEER('CN=DISPENSE.PAYMENTS.ANCHORBANK.PVT*') +
  USERSRC(MAP) MCAUSER('mq_dispense') ACTION(REPLACE)

* --- Default deny for everyone else ---
SET CHLAUTH(SETTLE.SVRCONN) TYPE(SSLPEERMAP) +
  SSLPEER('*') USERSRC(NOACCESS) ACTION(REPLACE)

* --- Authorities (OAM) ---
* Base connect to QM
SET AUTHREC PROFILE('SETTLE') OBJTYPE(QMGR) PRINCIPAL('mq_barter')   AUTHADD(CONNECT,INQ)
SET AUTHREC PROFILE('SETTLE') OBJTYPE(QMGR) PRINCIPAL('mq_dispense') AUTHADD(CONNECT,INQ)

* barter: write request, read response
SET AUTHREC PROFILE('PAYMENT.REQUEST')  OBJTYPE(QUEUE) PRINCIPAL('mq_barter')   AUTHADD(PUT,INQ)
SET AUTHREC PROFILE('PAYMENT.RESPONSE') OBJTYPE(QUEUE) PRINCIPAL('mq_barter')   AUTHADD(GET,BROWSE,INQ)

* dispense: read-only (no PUT)
SET AUTHREC PROFILE('PAYMENT.REQUEST')  OBJTYPE(QUEUE) PRINCIPAL('mq_dispense') AUTHADD(GET,BROWSE,INQ)
SET AUTHREC PROFILE('PAYMENT.RESPONSE') OBJTYPE(QUEUE) PRINCIPAL('mq_dispense') AUTHADD(GET,BROWSE,INQ)

* --- Refresh security ---
REFRESH SECURITY TYPE(CONNAUTH)
REFRESH SECURITY TYPE(AUTHSERV)
REFRESH SECURITY TYPE(SSL)

END
EOF

echo "Done. QM=${QM}, Channel=SETTLE.SVRCONN, Port=${PORT}"
