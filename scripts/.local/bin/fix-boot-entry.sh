#!/usr/bin/env bash
# Recreate the UEFI boot entry after Acer firmware purges it.
# RUN FROM THE ARCH LIVE USB, not from the installed system.
#
#   mount -o subvol=@ /dev/nvme0n1p2 /mnt
#   mount /dev/nvme0n1p1 /mnt/boot
#   ./fix-boot-entry.sh
#   umount -R /mnt && reboot

set -euo pipefail

DISK="/dev/nvme0n1"
PART="1"
LOADER='\EFI\Microsoft\Boot\bootmgfw.efi'

if [[ ! -f /mnt/boot/EFI/systemd/systemd-bootx64.efi ]]; then
    echo "ERROR: /mnt/boot is not mounted, or systemd-boot is missing." >&2
    exit 1
fi

mkdir -p /mnt/boot/EFI/Microsoft/Boot
cp /mnt/boot/EFI/systemd/systemd-bootx64.efi \
   /mnt/boot/EFI/Microsoft/Boot/bootmgfw.efi

efibootmgr --create --disk "${DISK}" --part "${PART}" \
  --label "Windows Boot Manager" \
  --loader "${LOADER}" --unicode

echo
echo "Done. Current entries:"
efibootmgr
