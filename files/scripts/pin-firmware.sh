#!/usr/bin/env bash
# Pin linux-firmware to 20260221-1.fc43 to avoid sleep/wake regression
# introduced in 20260309-1.fc45. See: Projects/debug MEMORY.md
set -oue pipefail

FIRMWARE_VERSION="20260221"
FIRMWARE_RELEASE="1.fc43"
KOJI_BASE="https://kojipkgs.fedoraproject.org/packages/linux-firmware/${FIRMWARE_VERSION}/${FIRMWARE_RELEASE}/noarch"

PACKAGES=(
  amd-gpu-firmware
  amd-ucode-firmware
  atheros-firmware
  brcmfmac-firmware
  cirrus-audio-firmware
  intel-audio-firmware
  intel-gpu-firmware
  intel-vsc-firmware
  iwlegacy-firmware
  iwlwifi-dvm-firmware
  iwlwifi-mld-firmware
  iwlwifi-mvm-firmware
  libertas-firmware
  linux-firmware
  linux-firmware-whence
  mt7xxx-firmware
  nvidia-gpu-firmware
  nxpwireless-firmware
  qcom-wwan-firmware
  realtek-firmware
  tiwilink-firmware
)

URLS=()
for pkg in "${PACKAGES[@]}"; do
  URLS+=("${KOJI_BASE}/${pkg}-${FIRMWARE_VERSION}-${FIRMWARE_RELEASE}.noarch.rpm")
done

rpm-ostree override replace "${URLS[@]}"
