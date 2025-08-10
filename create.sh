#!/bin/bash

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
figlet "k3s like I'm five!" -f ~+/.fonts/standard.flf
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
echo ""
# Display the chosen template ID in a large ASCII art format
echo "${BOLD}${GREEN}"
echo "${BOLD}You entered:${RESET}"
figlet $VMTID -f ~+/.fonts/standard.flf
echo ""
echo "A template will be created unless $VMTID already exists" && \
read -p "as a template, VM or LXC. Do you wish to proceed? (yes or no)?" yn

case $yn in
  yes ) echo "OK, checking for existing templates...";;
   no ) echo "Stopping...no files were created, modified or deleted."; exit;;
    * ) echo "Invalid response."; exit 1;;
esac

# Check if the template ID exists - stop the script if it does to avoid
# damaging any existing nodes or templates.
echo ${BOLD}
if ls /etc/pve/nodes/*/qemu-server/$VMTID.conf 1> /dev/null 2>&1; then
    echo ${RESET}
    echo "${BOLD}${RED}Existing configuration located, please try again with a" | pv -qL 25
    echo "new ID number or remove the existing file which is located: ${RESET}" | pv -qL 25
    echo ${BOLD}
    echo /etc/pve/nodes/*/qemu-server/$VMTID.conf
    echo ${RESET}
    echo # Print a final newline after the animation
    exit 0
  else
    echo ""${GREEN}
    echo "No existing template for $VMTID was located, proceeding" && \
    echo "with template creation... standby"${RESET}
fi


# Create the template
echo "Creating template with ID: $VMTID"
echo "This may take a few minutes, please be patient..."
sleep 2
qm create $VMTID --name "debian-13-cloudimg" --ostype l26 --cpu host --cores 2 --memory 2048 \
  --net0 virtio,bridge=vmbr0,tag=15 --scsihw virtio-scsi-pci
qm set $VMTID --scsi0 thin1:0,import-from=/root/images/debian-13-cloud.raw
qm set $VMTID --ide2 thin1:cloudinit
qm set $VMTID --boot order=scsi0
qm set $VMTID --tags debian,13,cloud,trixie
qm set $VMTID --serial0 socket --vga serial0
qm set $VMTID --agent enabled=1
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
qm set $VMTID --cicustom vendor=/mnt/pve/cephfs/snippets/install-qemu-guest-agent.yaml
qm set $VMTID --ipconfig0 ip=dhcp
qm template $VMTID
echo ""
echo "${BOLD}${GREEN}Template $VMTID created successfully!${RESET}"
echo "Exporting relevant environment variables... to .environment file"
echo "export VMTID=$VMTID" > ~+/.template.env
echo "export USER_NAME=$USER_NAME" >> ~+/.template.env
echo "export HASHED_PASSWORD=$HASHED_PASSWORD" >> ~+/.template.env
exit 0
# End of script
echo "${BOLD}${GREEN}Template creation completed!${RESET}"
echo "You can now use this template to deploy new VMs in Proxmox."
echo "To start immediately run build.sh next!"