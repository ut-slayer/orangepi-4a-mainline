#!/bin/bash

set -e

USB_MOUNT="/mnt/usb"
EMMC="/dev/mmcblk2"

echo "=========================================="
echo " Orange Pi 4A - eMMC Image Installer"
echo "=========================================="
echo
echo "Before continuing:"
echo
echo "1. Copy the desired .img file(s) to a USB flash drive."
echo "2. Insert the USB flash drive into the Orange Pi 4A."
echo "3. Press ENTER after the USB drive has been inserted."
echo
read -r -p "Press ENTER to continue..."

echo
echo "Detecting USB storage device..."
echo

USB_PARTITION=$(lsblk -rpno NAME,TYPE,FSTYPE | awk '$2=="part" && $3!="" && $1 !~ /mmcblk/ {print $1; exit}')

if [ -z "$USB_PARTITION" ]; then
    echo "ERROR: No USB storage partition was detected."
    echo "Please insert the USB flash drive and run the script again."
    exit 1
fi

echo "USB partition detected: $USB_PARTITION"

sudo mkdir -p "$USB_MOUNT"

if ! mountpoint -q "$USB_MOUNT"; then
    echo "Mounting USB drive..."

    FSTYPE=$(lsblk -no FSTYPE "$USB_PARTITION")

    if [ "$FSTYPE" = "exfat" ]; then
        if command -v mount.exfat-fuse >/dev/null 2>&1; then
            sudo mount.exfat-fuse "$USB_PARTITION" "$USB_MOUNT"
        else
            echo "ERROR: exFAT filesystem detected, but exfat-fuse is not installed."
            echo
            echo "Install it with:"
            echo "  sudo apt update"
            echo "  sudo apt install exfat-fuse exfatprogs"
            exit 1
        fi
    else
        sudo mount "$USB_PARTITION" "$USB_MOUNT"
    fi
fi

echo
echo "USB drive mounted at: $USB_MOUNT"
echo

if [ ! -b "$EMMC" ]; then
    echo "ERROR: eMMC device was not found at $EMMC"
    exit 1
fi

mapfile -t IMAGES < <(
    find "$USB_MOUNT" -maxdepth 1 -type f -name "*.img" | sort
)

if [ ${#IMAGES[@]} -eq 0 ]; then
    echo "ERROR: No .img files were found on the USB drive."
    echo
    echo "Copy at least one .img file to the USB drive and try again."
    exit 1
fi

echo "Available images:"
echo

for i in "${!IMAGES[@]}"; do
    SIZE=$(du -h "${IMAGES[$i]}" | cut -f1)
    echo "$((i+1))) $(basename "${IMAGES[$i]}") [$SIZE]"
done

echo
read -r -p "Select the image to install [1-${#IMAGES[@]}]: " CHOICE

if ! [[ "$CHOICE" =~ ^[0-9]+$ ]]; then
    echo "ERROR: Invalid selection."
    exit 1
fi

INDEX=$((CHOICE - 1))

if [ "$INDEX" -lt 0 ] || [ "$INDEX" -ge "${#IMAGES[@]}" ]; then
    echo "ERROR: Selection out of range."
    exit 1
fi

IMAGE="${IMAGES[$INDEX]}"

echo
echo "Selected image:"
echo "  $(basename "$IMAGE")"
echo
echo "Target eMMC device:"
echo "  $EMMC"
echo

echo "Current storage layout:"
echo
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL
echo

echo "=========================================================="
echo " WARNING"
echo "=========================================================="
echo
echo "The eMMC device $EMMC will be COMPLETELY ERASED."
echo
echo "All existing partitions, files, and operating systems"
echo "currently stored on the eMMC will be permanently deleted."
echo
echo "Selected image:"
echo "  $(basename "$IMAGE")"
echo
echo "Target:"
echo "  $EMMC"
echo
read -r -p "Type ERASE to confirm and continue: " CONFIRM

if [ "$CONFIRM" != "ERASE" ]; then
    echo
    echo "Operation cancelled."
    exit 0
fi

echo
echo "Unmounting any mounted eMMC partitions..."

sudo umount ${EMMC}p* 2>/dev/null || true

echo
echo "Writing image to eMMC..."
echo

sudo dd \
    if="$IMAGE" \
    of="$EMMC" \
    bs=4M \
    status=progress \
    conv=fsync

echo
echo "Synchronizing data..."
sync

echo
echo "Image successfully written to eMMC."
echo

echo "New storage layout:"
echo
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS

echo
echo "=========================================="
echo " Installation completed successfully"
echo "=========================================="
echo
echo "Next steps:"
echo
echo "1. Power off the Orange Pi."
echo "2. Remove the SD card."
echo "3. Remove the USB flash drive."
echo "4. Power the Orange Pi back on."
echo "5. The system should now boot from eMMC."
echo

read -r -p "Power off now? [y/N]: " POWER

if [[ "$POWER" =~ ^[yY]$ ]]; then
    sudo poweroff
fi
