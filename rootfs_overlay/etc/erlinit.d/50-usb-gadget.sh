#!/bin/sh

# USB gadget initialization is optional. Never abort system boot on errors.
set -u

GADGET_ROOT="/sys/kernel/config/usb_gadget"
GADGET_DIR="$GADGET_ROOT/luckfox_pico"
CONFIG_DIR="$GADGET_DIR/configs/c.1"
USB_DEVICE_IP="${LUCKFOX_USB_DEVICE_IP:-192.168.100.1/24}"
USB_HOST_MAC="${LUCKFOX_USB_HOST_MAC:-02:1A:11:00:00:01}"
USB_DEV_MAC="${LUCKFOX_USB_DEV_MAC:-02:1A:11:00:00:02}"

log_msg() {
  echo "50-usb-gadget: $*" >/dev/kmsg 2>/dev/null || true
}

first_udc() {
  for p in /sys/class/udc/*; do
    [ -e "$p" ] || continue
    echo "${p##*/}"
    return 0
  done
  return 1
}

if [ ! -r /proc/mounts ]; then
  mount -t proc proc /proc 2>/dev/null || true
fi

mkdir -p /sys
if ! grep -q " /sys sysfs " /proc/mounts 2>/dev/null; then
  mount -t sysfs sysfs /sys 2>/dev/null || true
fi

mkdir -p /sys/kernel/config
if ! grep -q " /sys/kernel/config configfs " /proc/mounts 2>/dev/null; then
  # If configfs is unavailable, skip USB gadget setup and continue boot.
  if ! mount -t configfs none /sys/kernel/config 2>/dev/null; then
    exit 0
  fi
fi

mkdir -p "$GADGET_DIR"

CURRENT_UDC="$(tr -d ' \t\r\n' < "$GADGET_DIR/UDC" 2>/dev/null || true)"
if [ -n "$CURRENT_UDC" ] && [ -d "$CONFIG_DIR" ] && [ -e "$CONFIG_DIR/acm.usb0" ] && [ -e "$CONFIG_DIR/ecm.usb0" ]; then
  exit 0
fi

# If gadget state is partial or stale, unbind and rebuild the config.
if [ -n "$CURRENT_UDC" ]; then
  echo "" > "$GADGET_DIR/UDC" 2>/dev/null || true
fi

echo 0x1d6b > "$GADGET_DIR/idVendor"
echo 0x0104 > "$GADGET_DIR/idProduct"
echo 0x0100 > "$GADGET_DIR/bcdDevice"
echo 0x0200 > "$GADGET_DIR/bcdUSB"

SERIAL="$(tr -d '\000' < /proc/device-tree/serial-number 2>/dev/null || true)"
[ -n "$SERIAL" ] || SERIAL="luckfox-pico"

mkdir -p "$GADGET_DIR/strings/0x409"
echo "$SERIAL" > "$GADGET_DIR/strings/0x409/serialnumber"
echo "Luckfox" > "$GADGET_DIR/strings/0x409/manufacturer"
echo "Luckfox Pico USB Gadget" > "$GADGET_DIR/strings/0x409/product"

mkdir -p "$CONFIG_DIR/strings/0x409"
echo "CDC ACM + CDC ECM" > "$CONFIG_DIR/strings/0x409/configuration"
echo 250 > "$CONFIG_DIR/MaxPower"

[ -d "$GADGET_DIR/functions/acm.usb0" ] || mkdir -p "$GADGET_DIR/functions/acm.usb0"
[ -d "$GADGET_DIR/functions/ecm.usb0" ] || mkdir -p "$GADGET_DIR/functions/ecm.usb0"
[ -d "$GADGET_DIR/functions/acm.usb0" ] || {
  log_msg "failed to create acm.usb0 (CONFIG_USB_CONFIGFS_ACM may be disabled)"
  exit 0
}
[ -d "$GADGET_DIR/functions/ecm.usb0" ] || {
  log_msg "failed to create ecm.usb0 (CONFIG_USB_CONFIGFS_ECM may be disabled)"
  exit 0
}
echo "$USB_HOST_MAC" > "$GADGET_DIR/functions/ecm.usb0/host_addr"
echo "$USB_DEV_MAC" > "$GADGET_DIR/functions/ecm.usb0/dev_addr"

[ -e "$CONFIG_DIR/acm.usb0" ] || /bin/busybox ln -s "$GADGET_DIR/functions/acm.usb0" "$CONFIG_DIR/acm.usb0" 2>/dev/null
[ -e "$CONFIG_DIR/acm.usb0" ] || {
  log_msg "failed to create acm.usb0 symlink (ln applet may be unavailable)"
  exit 0
}
[ -e "$CONFIG_DIR/ecm.usb0" ] || /bin/busybox ln -s "$GADGET_DIR/functions/ecm.usb0" "$CONFIG_DIR/ecm.usb0" 2>/dev/null
[ -e "$CONFIG_DIR/ecm.usb0" ] || {
  log_msg "failed to create ecm.usb0 symlink (ln applet may be unavailable)"
  exit 0
}

UDC=""
for _ in 1 2 3 4 5; do
  UDC="$(first_udc || true)"
  [ -n "$UDC" ] && break
  sleep 1
done

[ -n "$UDC" ] || exit 0
echo "$UDC" > "$GADGET_DIR/UDC"

if command -v ip >/dev/null 2>&1; then
  ip link set usb0 up || true
  ip addr add "$USB_DEVICE_IP" dev usb0 2>/dev/null || true
fi
