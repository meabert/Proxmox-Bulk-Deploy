#!/bin/bash

source .template.env
if [[ ! -f .template.env ]]; then
  echo "Error: .template.env not found, create a template using"
  echo "Make a VM template first using create.sh, then use build.sh."
  exit 1
fi
RESET=$(tput sgr0)   BOLD=$(tput bold)
BLACK=$(tput setaf 0) RED=$(tput setaf 1)
GREEN=$(tput setaf 2) YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4) MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6) WHITE=$(tput setaf 7)
DEFAULT_COLOR=$(tput setaf 9)
echo "${BOLD}${GREEN}"
figlet "k3s like I'm five!" -f ~+/.fonts/standard.flf
figlet "Bulk VM Creator" -f ~+/.fonts/standard.flf
# Print a message to the user about the template creation process
echo "${RESET}"
echo "${BOLD}${DEFAULT_COLOR}"
set -e
# Check for required commands
for cmd in figlet qm openssl pv; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: Required command '$cmd' is not installed or not in PATH. "
    exit 1
  fi
done
# validate the template ID #
echo "${WHITE}" && read -p "The ID for the Template I have as $VMTID correct? (yes or no) " yn

case $yn in
  yes ) echo "OK, proceeding...";;
  no ) echo "Exiting...no files were created, modified or deleted."; exit;;
  * ) echo "Invalid response"; exit 1;;
esac

text="Stanby while we get things ready, I'll collect your order in one moment. "
for (( i=0; i<${#text}; i++ )); do
    echo -n "${text:$i:1}"
    sleep 0.04
done
echo
export NUM1=$VMTID && export NUM2=100 && VM1=$((NUM1+NUM2))
export NUM1=$VMTID && export NUM2=200 && VM2=$((NUM1+NUM2))
export NUM1=$VMTID && export NUM2=300 && VM3=$((NUM1+NUM2))
echo "Server: $VM1 Worker: $VM2 HAProxy: $VM3"
figlet "Server: $VM1" -f .fonts/standard.flf
figlet "Worker: $VM2" -f .fonts/standard.flf
figlet "HAProxy: $VM3" -f .fonts/standard.flf
sleep 5

# Define the number of VM's to create per appliance
clear
echo "${BOLD}${GREEN}"
figlet "k3s like I'm five!" -f .fonts/standard.flf
figlet "Server Nodes" -f .fonts/standard.flf
echo ""

while true; do
    echo ""
    read -p "How many Server Nodes do you want? " REPETITIONS
    clear
    if [[ -z "$REPETITIONS" ]]; then
        echo "Error: Input cannot be empty. Please try again."
    elif [[ ! "$REPETITIONS" =~ ^[0-9]+$ ]]; then
        echo "Error: Input must contain only numbers. Please try again."
    elif [[ "$REPETITIONS" -lt 1 || "$REPETITIONS" -gt 10 ]]; then
        echo "Error: Input must be a number between 1 and 10. Please try again."
    else
        echo "Valid input received: $REPETITIONS"
        break
    fi
done

echo "Creating $REPETITIONS Server Nodes..."

for (( i=1; i<=REPETITIONS; i++ )); do
    VMID_NEW=$((VM1 + i - 1))
    VMNAME="k3s-srv$(printf "%02d" $i)"
    echo "Working on $VMNAME (ID: $VMID_NEW)... standby....."
    qm clone $VMTID $VMID_NEW --name $VMNAME
    qm resize $VMID_NEW scsi0 32G
    qm set $VMID_NEW --cpu host
    qm set $VMID_NEW --memory 4096
    qm set $VMID_NEW --cores 2
    qm set $VMID_NEW --ciupgrade 1
    qm set $VMID_NEW --ipconfig0 ip=dhcp
    sleep 1
    echo "$VMNAME completed"
    echo "$VMNAME" >> .server-nodes.env
    echo "VMID: $VMID_NEW" >> .server-nodes.env
done

echo "Bulk Server creation finished, moving on to Workers..."

# Define the number of Worker VM's to create per appliance
clear
echo "${BOLD}${GREEN}"
figlet "k3s like I'm five!" -f .fonts/standard.flf
figlet "Worker Nodes" -f .fonts/standard.flf
echo ""

while true; do
    echo ""
    read -p "How many Worker Nodes do you want? " REPETITIONS
    clear
    if [[ -z "$REPETITIONS" ]]; then
        echo "Error: Input cannot be empty. Please try again."
    elif [[ ! "$REPETITIONS" =~ ^[0-9]+$ ]]; then
        echo "Error: Input must contain only numbers. Please try again."
    elif [[ "$REPETITIONS" -lt 1 || "$REPETITIONS" -gt 10 ]]; then
        echo "Error: Input must be a number between 1 and 10. Please try again."
    else
        echo "Valid input received: $REPETITIONS"
        break
    fi
done

echo "Creating $REPETITIONS Worker Nodes..."

for (( i=1; i<=REPETITIONS; i++ )); do
    VMID_NEW=$((VM2 + i - 1))
    VMNAME="k3s-wkr$(printf "%02d" $i)"
    echo "Working on $VMNAME (ID: $VMID_NEW)... standby....."
    qm clone $VMTID $VMID_NEW --name $VMNAME
    qm resize $VMID_NEW scsi0 32G
    qm set $VMID_NEW --cpu host
    qm set $VMID_NEW --memory 8192
    qm set $VMID_NEW --cores 4
    qm set $VMID_NEW --ciupgrade 1
    qm set $VMID_NEW --ipconfig0 ip=dhcp
    sleep 1
    echo "$VMNAME completed"
    echo "$VMNAME" >> .server-nodes..env
    echo "VMID: $VMID_NEW" >> .server-nodes.env
done

echo "Bulk Worker creation finished, moving on to Load Balancers..."

# Define the number of VM's to create per appliance
clear
echo "${BOLD}${GREEN}"
figlet "k3s like I'm five!" -f .fonts/standard.flf
figlet "Load Balancers" -f .fonts/standard.flf
echo ""

while true; do
    echo ""
    read -p "How many Load Balancer VM's do you want ?" REPETITIONS
    clear
    if [[ -z "$REPETITIONS" ]]; then
        echo "Error: Input cannot be empty. Please try again."
    elif [[ ! "$REPETITIONS" =~ ^[0-9]+$ ]]; then
        echo "Error: Input must contain only numbers. Please try again."
    elif [[ "$REPETITIONS" -lt 1 || "$REPETITIONS" -gt 10 ]]; then
        echo "Error: Input must be a number between 1 and 10. Please try again."
    else
        echo "Valid input received: $REPETITIONS"
        break
    fi
done

# Loop 'REPETITIONS' times
echo "Creating $REPETITIONS Load Balancers..."

for (( i=1; i<=REPETITIONS; i++ )); do
    VMID_NEW=$((VM3 + i - 1))
    VMNAME="k3s-lb$(printf "%02d" $i)"
    echo "Working on $VMNAME (ID: $VMID_NEW)... standby....."
    qm clone $VMTID $VMID_NEW --name $VMNAME
    qm resize $VMID_NEW scsi0 32G
    qm set $VMID_NEW --cpu host
    qm set $VMID_NEW --memory 2048
    qm set $VMID_NEW --cores 2
    qm set $VMID_NEW --ciupgrade 1
    qm set $VMID_NEW --ipconfig0 ip=dhcp
    sleep 1
    echo "$VMNAME completed"
    echo "$VMNAME" >> .server-nodes.env
    echo "VMID: $VMID_NEW" >> .server-nodes.env
done

echo "All requested VM's have been created successfully!"
echo "You can find the list of created nodes in .server-nodes.txt"
echo "You can now proceed to configure your k3s cluster with these nodes."
echo "Remember to set up your k3s configuration files and networking as needed."
echo "Thank you for using the k3s bulk VM creator script!"
