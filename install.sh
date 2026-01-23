#!/usr/bin/env bash
set -euo pipefail

# ---------------------------
# Config
# ---------------------------
MQ_VERSION="9.4.4.0"
MQ_URL="https://public.dhe.ibm.com/ibmdl/export/pub/software/websphere/messaging/mqadv/${MQ_VERSION}-IBM-MQ-Advanced-for-Developers-LinuxX64.tar.gz"

WORKDIR="/tmp/ibm-mq-install"
LIMITS_FILE="/etc/security/limits.d/30-ibm-mq.conf"
NOFILE_LIMIT="65536"

INSTALL_JAVA="true"
CORRETTO_RPM_URL="https://corretto.aws/downloads/latest/amazon-corretto-21-x64-linux-jdk.rpm"

# ---------------------------
# Helpers
# ---------------------------
log(){ echo -e "\n[+] $*"; }
die(){ echo -e "\n[!] $*\n" >&2; exit 1; }

need_root(){
  [[ "$(id -u)" -eq 0 ]] || die "Run as root (sudo)."
}

pick_pm(){
  if command -v dnf >/dev/null 2>&1; then
    echo "dnf"
  elif command -v yum >/dev/null 2>&1; then
    echo "yum"
  else
    die "Neither dnf nor yum found."
  fi
}

pm_install(){
  local pm="$1"; shift
  $pm -y install "$@"
}

have_pkg(){
  # Works on both yum and dnf
  rpm -q "$1" >/dev/null 2>&1
}

cmd_exists(){ command -v "$1" >/dev/null 2>&1; }

os_id(){
  . /etc/os-release
  echo "${ID:-unknown}:${VERSION_ID:-unknown}"
}

# ---------------------------
# Main
# ---------------------------
need_root
PM="$(pick_pm)"
OS="$(os_id)"

log "OS detected: ${OS} (using package manager: ${PM})"

log "Install prerequisites"
# Core prereqs (available on AL2 + RHEL8/9)
BASE_PKGS=(
  bash bc ca-certificates file findutils gawk grep
  passwd procps-ng sed shadow-utils tar util-linux which wget
)
pm_install "$PM" "${BASE_PKGS[@]}"

# glibc-common exists on RHEL; not on Amazon Linux 2
if $PM -y info glibc-common >/dev/null 2>&1; then
  pm_install "$PM" glibc-common
else
  log "glibc-common not available on this distro (OK)."
fi

log "Ensure mqm user exists"
if ! id mqm >/dev/null 2>&1; then
  useradd --system --create-home --shell /bin/bash mqm || useradd mqm
else
  log "mqm already exists."
fi

log "Set nofile limits in ${LIMITS_FILE}"
cat > "${LIMITS_FILE}" <<EOF
# IBM MQ - nofile limits
mqm  soft  nofile  ${NOFILE_LIMIT}
mqm  hard  nofile  ${NOFILE_LIMIT}
root soft  nofile  ${NOFILE_LIMIT}
root hard  nofile  ${NOFILE_LIMIT}
EOF

log "Prepare work directory: ${WORKDIR}"
rm -rf "${WORKDIR}"
mkdir -p "${WORKDIR}"
cd "${WORKDIR}"

log "Download IBM MQ Advanced for Developers ${MQ_VERSION}"
wget -q --show-progress -O mqadv.tgz "${MQ_URL}"

log "Extract MQ package"
tar -xzf mqadv.tgz

[[ -d "MQServer" ]] || die "MQServer directory not found after extract."

if [[ "${INSTALL_JAVA}" == "true" ]]; then
  log "Install Java (Amazon Corretto 21) if not present"
  if cmd_exists java; then
    log "Java already present: $(java -version 2>&1 | head -n 1)"
  else
    wget -q --show-progress -O corretto.rpm "${CORRETTO_RPM_URL}"
    # localinstall works on yum, install works on dnf; we try both safely
    if [[ "${PM}" == "yum" ]]; then
      yum -y localinstall ./corretto.rpm
    else
      dnf -y install ./corretto.rpm
    fi
  fi
fi

log "Install IBM MQ (skip if already installed)"
if cmd_exists dspmqver; then
  log "IBM MQ already installed. Version:"
  dspmqver || true
else
  cd "${WORKDIR}/MQServer"

  log "Accept MQ license"
  chmod +x ./mqlicense.sh
  ./mqlicense.sh -text_only -accept

  log "Install MQ RPMs"
  # Use PM so dependencies/order are handled
  $PM -y install ./*.rpm
fi

log "Optional: systemd drop-in for higher NOFILE (if MQ service units exist)"
# IBM MQ services/units vary; create a generic drop-in for any MQ unit you later enable
mkdir -p /etc/systemd/system.conf.d
cat > /etc/systemd/system.conf.d/90-ibm-mq-nofile.conf <<EOF
[Manager]
DefaultLimitNOFILE=${NOFILE_LIMIT}
EOF
systemctl daemon-reexec >/dev/null 2>&1 || true

log "Verify MQ install"
if cmd_exists dspmqver; then
  dspmqver
else
  die "dspmqver not found; MQ install likely failed."
fi

log "Done."
echo "Notes:"
echo " - Re-login (or reboot) recommended to fully apply PAM limits."
echo " - MQ environment helper: . /opt/mqm/bin/setmqenv -s   (if /opt/mqm exists)"
echo " - If you plan to run a QM, consider also tuning kernel params + ulimits per IBM MQ docs."
