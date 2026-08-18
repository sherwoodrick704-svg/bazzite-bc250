#!/usr/bin/bash
# Builds the BC250 additions INTO the image:
#   1. cyan-skillfish GPU governor  (filippor COPR)
#   2. CoolerControl + liquidctl     (Terra repo)  -> fan curves
#   3. nct6687 fan driver            (compiled against THIS image's kernel)
# Runs during the image build in GitHub Actions. If any step fails the whole
# build fails (good — we want to know immediately, not ship a broken image).
set -euxo pipefail

### --- figure out exactly which kernel is in this image -------------------
# (uname -r would give the CI runner's kernel, which is wrong — read it from
#  the image's modules dir instead.)
KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-core 2>/dev/null | head -1)"
[ -n "${KVER}" ] || KVER="$(ls -1 /usr/lib/modules | head -1)"
echo ">>> Building for kernel: ${KVER}"

### --- 1. GPU governor -----------------------------------------------------
# The package that unsticks the BC250 GPU clock (what we fixed by hand).
dnf5 -y copr enable filippor/bazzite || dnf5 -y copr enable filippor/cyan-skillfish-governor
dnf5 -y install cyan-skillfish-governor-smu
systemctl enable cyan-skillfish-governor-smu.service || true

### --- 2. CoolerControl (fan curves) --------------------------------------
# Terra repo hosts coolercontrol; add it if the base image doesn't have it.
if ! dnf5 -y install coolercontrol coolercontrold liquidctl ; then
  dnf5 -y install dnf5-plugins || true
  dnf5 -y config-manager addrepo --from-repofile=https://repos.fyralabs.com/terra43/terra.repo
  dnf5 -y install coolercontrol coolercontrold liquidctl
fi
systemctl enable coolercontrold.service || true

### --- 3. nct6687 fan driver (the whole reason we need a custom image) -----
# Install the toolchain + kernel-devel that MATCHES this image's kernel.
dnf5 -y install gcc make git
dnf5 -y install "kernel-devel-${KVER}" \
  || dnf5 -y install "kernel-bazzite-devel-${KVER}" \
  || dnf5 -y install kernel-devel

git clone --depth=1 https://github.com/Fred78290/nct6687d /tmp/nct6687d
make -C /tmp/nct6687d KVERSION="${KVER}"
install -Dm644 "/tmp/nct6687d/nct6687.ko" "/usr/lib/modules/${KVER}/extra/nct6687.ko"
depmod -a "${KVER}"

# Load nct6687 at boot; blacklist the read-only nct6683 so it doesn't win.
echo 'nct6687' > /usr/lib/modules-load.d/nct6687.conf
printf 'blacklist nct6683\noptions nct6687 force=true\n' > /usr/lib/modprobe.d/nct6687-bc250.conf

### --- cleanup so the image stays lean ------------------------------------
dnf5 -y remove gcc make git 'kernel-devel*' 'kernel-bazzite-devel*' || true
rm -rf /tmp/nct6687d
dnf5 clean all || true
rm -rf /var/* || true
echo ">>> BC250 build steps complete."
