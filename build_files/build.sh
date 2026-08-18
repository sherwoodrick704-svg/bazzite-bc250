#!/usr/bin/bash
set -euxo pipefail

KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-core 2>/dev/null | head -1)"
[ -n "${KVER}" ] || KVER="$(ls -1 /usr/lib/modules | head -1)"
echo ">>> Building for kernel: ${KVER}"

### 1. GPU governor
dnf5 -y copr enable filippor/bazzite || dnf5 -y copr enable filippor/cyan-skillfish-governor
dnf5 -y install cyan-skillfish-governor-smu
systemctl enable cyan-skillfish-governor-smu.service || true

### 2. CoolerControl  (NON-FATAL)
dnf5 -y config-manager setopt terra.enabled=1 2>/dev/null || true
dnf5 -y install coolercontrol coolercontrold liquidctl \
  || dnf5 -y --enablerepo='terra*' install coolercontrol coolercontrold liquidctl \
  || echo "WARN: coolercontrol not baked in (run 'ujust install-coolercontrol' after rebase)"
systemctl enable coolercontrold.service 2>/dev/null || true

### 3. nct6687 fan driver  (ESSENTIAL)
dnf5 -y install gcc make git
if ! dnf5 -y install "kernel-devel-${KVER}"; then
  dnf5 -y copr enable bazzite-org/bazzite || true
  dnf5 -y install "kernel-devel-${KVER}"
fi
test -d "/usr/src/kernels/${KVER}" || { echo "FATAL: no kernel-devel matching ${KVER}"; exit 1; }

git clone --depth=1 https://github.com/Fred78290/nct6687d /tmp/nct6687d
make -C /tmp/nct6687d TARGET="${KVER}"
KO="$(find /tmp/nct6687d -name 'nct6687.ko' | head -1)"
test -n "${KO}" || { echo "FATAL: nct6687.ko not produced"; exit 1; }
install -Dm644 "${KO}" "/usr/lib/modules/${KVER}/extra/nct6687.ko"
depmod -a "${KVER}"
echo 'nct6687' > /usr/lib/modules-load.d/nct6687.conf
printf 'blacklist nct6683\noptions nct6687 force=true\n' > /usr/lib/modprobe.d/nct6687-bc250.conf

### cleanup
dnf5 -y remove gcc make git 'kernel-devel*' || true
rm -rf /tmp/nct6687d
dnf5 clean all || true
rm -rf /var/* || true
echo ">>> BC250 build steps complete."
