#!/bin/bash
#!/usr/bin/env bash

# --- Defaults ---
SOURCE_IMAGE=""
DISK_SIZE="10G"    # used only if you later add a "blank disk" mode

usage() {
  echo ""
  echo "Usage: $0 --image /path/to/disk.qcow2"
  echo "Be sure to specify the path to the desired image when running the command"
  echo "--image PATH     Path to a qcow2/raw disk image to import (required)"
  # echo "--allow-blank    Proceed without an image (creates blank disk of --size)  [optional]"
  # echo "--size SIZE      Disk size for blank disk mode (e.g., 20G)               [optional]"
  echo ""
}

die() { echo "Error: $*" >&2; exit 2; }

# --- Parse args ---
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --image)
      [[ -n "${2:-}" ]] || { usage; die "--image requires a path"; }
      SOURCE_IMAGE="$2"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown option: $1" >&2; usage; exit 2 ;;
  esac
done

# --- Required: image must exist and be readable ---
if [[ -z "$SOURCE_IMAGE" ]]; then
  usage
  die "Please provide a disk image with: $0 --image /root/images/debian-13-generic.qcow2"
fi

if [[ ! -f "$SOURCE_IMAGE" || ! -r "$SOURCE_IMAGE" ]]; then
  die "Image not found or unreadable: $SOURCE_IMAGE"
fi

# --- Reject obvious ISO usage for import mode, but offer a conversion ---
case "${SOURCE_IMAGE,,}" in
  *.iso)
    echo "⚠️  Detected ISO: $SOURCE_IMAGE"
    echo "Normally, --image expects a qcow2/raw disk. Attempting conversion..."

    # Decide on target format and name
    TARGET_IMAGE="${SOURCE_IMAGE%.iso}.qcow2"
    STORAGE_FMT="qcow2"   # or "raw" if you prefer

    # Optional: confirm with user
    read -rp "Convert ISO to $STORAGE_FMT at $TARGET_IMAGE? [y/N]: " yn
    case "$yn" in
      [Yy]*) ;;
      *) echo "Aborting."; exit 1 ;;
    esac

    # Use qemu-img convert
    if qemu-img convert -f raw -O "$STORAGE_FMT" "$SOURCE_IMAGE" "$TARGET_IMAGE"; then
      echo "✅ Conversion successful: $TARGET_IMAGE"
      SOURCE_IMAGE="$TARGET_IMAGE"
    else
      echo "❌ Conversion failed."
      exit 1
    fi
    ;;
esac

# --- Probe with qemu-img for extra sanity (if available) ---
if command -v qemu-img >/dev/null 2>&1; then
  if ! qemu-img info "$SOURCE_IMAGE" >/dev/null 2>&1; then
    die "qemu-img cannot read '$SOURCE_IMAGE' (unsupported or corrupt format)"
  fi
fi

# Check for stdin
if [ ! -t 0 ]; then
  echo "No terminal stdin available — run in interactive mode."
  exit 1
fi


# Check for required commands
for cmd in figlet qm openssl pv; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: Required command '$cmd' is not installed or not in PATH."
    exit 1
  fi
done

# Declare formatting variables for terminal output
# These variables are used to format the output text in the terminal, making it more readable and
# visually appealing. They include colors and styles for text formatting.

RESET=$(tput sgr0)    BOLD=$(tput bold)
BLACK=$(tput setaf 0) RED=$(tput setaf 1)
GREEN=$(tput setaf 2) YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)  MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6)  WHITE=$(tput setaf 7)

# Trap to handle script interruption
# This will ensure that if the script is interrupted (e.g., Ctrl+C), it exits safely
# and provides a message to the user.
trap 'echo -e "\n${RED}Script interrupted. Exiting safely.${RESET}"; exit 1' INT

# Halt the script on any error
# This ensures that if any command fails, the script will stop executing immediately.
set -e

# Display a welcome message using figlet
# This will print a large ASCII art text in the terminal to welcome the user.
clear
echo "${BOLD}""${GREEN}"
figlet "Proxmox Rapid Deploy" -f ~+/.fonts/standard.flf
figlet "Template Maker" -f ~+/.fonts/standard.flf
# Print a message to the user about the template creation process
echo "${RESET}"
echo "${BOLD}${W}"
echo "Pick a number for the VM Template ID, this should be a number that will"
echo "not conflict with any existing VM's or templates."
echo ""
echo "Example: VM Template ID '5000'"
echo "${RESET}"
# Loop to ensure valid input for $VMTID which is the Template/VM ID in Proxmox
# This will ensure that the user provides a valid number and not an empty input.
while true; do
    echo ""
    read -p "VM Template ID: " VMTID
    clear
    # Check if input is empty
    if [[ -z "$VMTID" ]]; then
        echo "Error: Input cannot be empty. Please try again."
    # Check if input contains only numbers
    elif [[ ! "$VMTID" =~ ^[0-9]+$ ]]; then
        echo "Error: Input must contain only numbers. Please try again."
    # Check if input is within the valid range (1000-999999) Proxmox soft-max is 1000000
    elif [[ "$VMTID" -lt 1000 || "$VMTID" -gt 999999 ]]; then
        echo "Error: Input must be a number between 1000 and 999999. Please try again."
    # Check if the ID already exists as a VM
    elif ls /etc/pve/nodes/*/qemu-server/$VMTID.conf 1> /dev/null 2>&1; then
        echo "Error: A VM or template with ID $VMTID already exists. Please choose a different ID."
    # Check if the ID already exists as an LXC container
    elif ls /etc/pve/nodes/*/lxc/$VMTID.conf 1> /dev/null 2>&1; then
        echo "Error: A container with ID $VMTID already exists. Please choose a different ID."
    # Validation complete, exit the loop
    else
        echo "Valid input received: $VMTID"
        break
    fi
done
clear
# Display the chosen template ID in a large ASCII art format
echo "${BOLD}${GREEN}"
echo "${BOLD}You entered:${RESET}" | pv -qL 50
figlet $VMTID -f ~+/.fonts/standard.flf | pv -qL 100
echo ""
echo "A template will be created unless $VMTID already exists" | pv -qL 50
echo "we are checking on this now...please be patient this may" | pv -qL 25
echo "take several minutes..${RESET}" | pv -qL 50

# Check if the template ID exists - stop the script if it does to avoid
# damaging any existing nodes or templates.
if ls /etc/pve/nodes/*/qemu-server/$VMTID.conf 1> /dev/null 2>&1; then
    echo "${BOLD}${RED}Existing configuration located, please try again with a" | pv -qL 25
    echo "new ID number or remove the existing file which is located: ${RESET}${BOLD}" | pv -qL 50
    echo /etc/pve/nodes/*/qemu-server/$VMTID.conf
    echo ${RESET}
    echo # Print a final newline after the animation
    exit 0
  else
    echo ""${GREEN}
    echo "✅ No existing template for $VMTID was located, proceeding" | pv -qL 25
    echo "with template creation... standby${RESET}" | pv -qL 50
fi

# Create the template
echo "Creating template with ID: $VMTID" | pv -qL 25
echo "This may take a few minutes, please be patient..." | pv -qL 50

sleep 1
echo "${RESET}${WHITE}"

# Pick the storage ID only (not the volume)
STORAGE_TARGET="$(
  /root/scripts/storage-selector.py /root/images/debian-13-generic.qcow2
)" || exit 1

SOURCE_IMAGE="/root/images/debian-13-generic.qcow2"

# Basic validation
if [[ -z "$STORAGE_TARGET" ]]; then
  echo "❌ No storage selected."
  exit 1
fi
if [[ ! -f "$SOURCE_IMAGE" ]]; then
  echo "❌ Source image not found: $SOURCE_IMAGE"
  exit 1
fi

echo "Using storage: $STORAGE_TARGET"
echo ""

# Build full volume spec for import mode
VOLUME_SPEC="${STORAGE_TARGET}:0,import-from=${SOURCE_IMAGE}"

# Show the actual path of where :0 would map, for operator sanity
if ! pvesm path "${STORAGE_TARGET}:0" >/dev/null 2>&1; then
  echo "ℹ️  Note: ${STORAGE_TARGET}:0 not yet allocated; path shown below will be placeholder"
else
  echo "Template will reside on: $(pvesm path ${STORAGE_TARGET}:0)"
fi

# Create VM
qm create "$VMTID" \
  --name "debian-13-cloudimg" \
  --ostype l26 \
  --cpu host \
  --cores 2 \
  --memory 2048 \
  --net0 virtio,bridge=vmbr0,tag=15 \
  --scsihw virtio-scsi-pci

# Attach imported disk
qm set "$VMTID" --scsi0 "$VOLUME_SPEC"

# Add cloud-init disk
qm set "$VMTID" --ide2 "${STORAGE_TARGET}:cloudinit"

# Misc config
qm set "$VMTID" --boot order=scsi0
qm set "$VMTID" --tags debian,13,cloudinit
qm set "$VMTID" --serial0 socket --vga serial0
qm set "$VMTID" --agent enabled=1

echo "✅ VM $VMTID created and configured."

echo ""
read -p "Enter username for cloud-init user: " USER_NAME
echo ""
# Generate a random salt for the password
SALT=$(openssl rand -base64 12)
# Prompt for the password securely
echo "Generated Hashed Password: $HASHED_PASSWORD"
read -s -p "Enter password for cloud-init user: " PLAIN_PASSWORD
echo ""
# Hash the password using SHA-512 and the generated salt
HASHED_PASSWORD=$(openssl passwd -6 -salt "$SALT" "$PLAIN_PASSWORD")
qm set $VMTID --ciuser $USER_NAME --cipassword "$HASHED_PASSWORD"
qm set $VMTID --cicustom vendor=cephfs:snippets/install-qemu-guest-agent.yaml
qm set $VMTID --ipconfig0 ip=dhcp
qm template $VMTID
echo ""
echo "${BOLD}${GREEN}Template $VMTID created successfully!${RESET}"
echo "Exporting relevant environment variables... to .template.env"
echo "feel free to use these variables to expand functionality."
echo "export VMTID=$VMTID" > ~+/.template.env
echo "Exporting the template ID......................." | pv -qL 50
ecoo "................................................" | pv -qL 50
echo "export USER_NAME=$USER_NAME" >> ~+/.template.env
echo "Exporting default user ID......................." | pv -qL 50
ecoo "................................................" | pv -qL 50
echo "export HASHED_PASSWORD=$HASHED_PASSWORD" >> ~+/.template.env
echo "Exporting password hash (keep secure)..........." | pv -qL 50
ecoo "................................................" | pv -qL 50
echo "export STORAGE_TARGET=$STORAGE_TARGET" >> ~+/.template.env
echo "Exporting the storage target...................." | pv -qL 50
ecoo "................................................" | pv -qL 50
echo "# $(date -Is) imported image: $SOURCE_IMAGE" >> ~+/.template.env
echo "Exporting image details........................." | pv -qL 50
ecoo "................................................" | pv -qL 50
exit 0
# End of script
echo "${BOLD}${GREEN} ✅ Template creation completed!${RESET}"
echo "You can now use this template to deploy new VMs in Proxmox."
echo "To start immediately run build.sh next!"
