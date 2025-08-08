# Proxmox Rapid VM Deployment Scripts

## Templates and Clones

[![pre-commit](https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit)](https://github.com/pre-commit/pre-commit)

- [x] Functional two-step script
- [x] Hardware agnostic
- [ ] Add visual metrics - in addition to logging
- [ ] Add ZFS - other options (scripts are pre-configured with LVM-Thin)
- [ ] Options to autoinstall various configurations of K3S
- [ ] Create fork for Talos flavors
- [ ] Addititional OS choices (Debian, Rocky, Arch, Alpine)
- [ ] Automated killswitch script (shut everything down in one press)
- [ ] Realign and map environment for VM's as they're created / destroyed
- [ ] Automate some SDN tasks - Simplistic Infrastructure as Code

This is desinged to be simple press and go script that is system agnostic
with minimal to no additional configuration required compared to other
tools like Ansible, Packer or Terraform.

[!TIP]
For best performance and ease of use, it is recommended to run these scripts
locally and stream ISO/Images from offload such as a NAS, SAN, or similar
Deploying many VM's at the same time will place significant strain on the
network. One can greatly improve the performance of the deployment if there
are multiple nodes to store images on.

With this tool you can easily have a 20+ node cluster up and running in a matter
of minutes.This is of course assuming you have the hardware, network, additional
nodes and storage to support all of it. My present homelab setup consists of
three proxmox nodes, 25Gb ethernet, at least 128GB RAM each, one local NVMe
drive per node and a Ceph storage pool.

Please note these scripts are presently configured to use username/password
authentication, but you can easily modify them to use SSH key authentication by
changing the `ssh` command in the scripts to include the `-i` flag with your
private key file. The current scripts will also prompt you for a global username
and password when a template is first created, use this for initial setup and
flip the switch to key-authentication later on when you are ready to go to production.

At this time I have these scripts setup for LVM-thin storage, but you can easily
modify the `create.sh` and `build.sh` scripts to use other storage types such as
ZFS, Ceph, or other storage backends supported by Proxmox. I do plan on adding
selection prompts in the future for you to choose the storage type, but for now
you can simply edit the scripts to change the storage type to your liking.

### Proxmox Cloud-Init Template Generator

```bash
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
echo "Pick a template number, round numbers in the thousands"
echo "provide plenty of room for all the nodes plus easy"
echo "organization, fast expansion and reduced resource use"
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
qm create $VMTID --name "talos-1.10.6" --ostype l26 --cpu host --cores 2 --memory 2048 \
  --net0 virtio,bridge=vmbr0,tag=15 --scsihw virtio-scsi-pci
qm set $VMTID --scsi0 thin1:0,import-from=athena:iso/noble-server-cloudimg-amd64.img
qm set $VMTID --ide2 thin1:cloudinit
qm set $VMTID --boot order=scsi0
qm set $VMTID --tags talos,1.10.6
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
qm set $VMTID --cicustom vendor=local:snippets/install-qemu-guest-agent.yaml
qm set $VMTID --ipconfig0 ip=dhcp
qm template $VMTID
echo ""
echo "${BOLD}${GREEN}Template $VMTID created successfully!${RESET}"
echo "Exporting relevant environment variables... to .environment file"
echo "export VMTID=$VMTID" > ~+/.template.env
echo "export USER_NAME=$USER_NAME" >> ~+/.template.env
exit 0
# End of script
echo "${BOLD}${GREEN}Template creation completed!${RESET}"
echo "You can now use this template to deploy new VMs in Proxmox."
```
