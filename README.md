

# Proxmox Bulk Deploy #

Deploy a large amount of generic/reusable VM's in a fast, safe and efficent
manner with the added plus of not requiring any large automation/deployment
solutions such as Terraform, Ansible, Chef or Salt..this script for the
most part should be portable between Linux distros.

## Templates and Clones ##

- [x] Functional two-step script
- [x] Hardware agnostic
- [x] Add visual metrics - in addition to logging
- [x] Add ZFS - other options (scripts are pre-configured with LVM-Thin)
- [ ] Options to autoinstall various configurations of K3S
- [ ] Create fork for Talos flavors
- [x] Addititional OS choices (VIA --image flag)
- [ ] Add automated image download to eliminate file management
- [ ] Automated killswitch script (shut everything down in one press)
- [ ] Realign and map environment for VM's as they're created / destroyed
- [ ] Automate some SDN tasks - Simplistic Infrastructure as Code

This is desinged to be simple press and go script that is system agnostic
with minimal to no additional configuration required compared to other
tools like Ansible, Packer or Terraform.

[!TIP]
> For best performance and ease of use, it is recommended to run these scripts
> locally and stream ISO/Images from offload such as a NAS, SAN, or similar
> Deploying many VM's at the same time will place significant strain on the
> network and drives. One can greatly improve the performance of the deployment
> if there are multiple nodes or drives to store images on exclusively.

[!NOTE]
This tool enables one to easily have a 20+ VM logical cluster up and running 
in a matter of minutes. This is of course assuming you have the hardware, 
network, additional nodes and storage to support all of it. 

[!WARNING]
> Please note these scripts are presently configured to use username/password
> authentication, the password will be stored as hashed value in a file after
> creation for record-keeping. Make sure you .gitignore this file since it will
> have sensitive information! SSH password authentication is standard however 
> if and when you are ready to make anything public facing you MUST switch to 
> key-authentication when you are ready to go to production.

[!CAUTION] Operator’s Oath**  
> 🚫 **Obscurity is not security** — bots don't care you put it on port 44523.”  
> 🔓 **Open ports are an open invitation** — and the guests don’t bring snacks.  
> 📊 **Know your threat level** — ignorance is a privilege your firewall can’t afford.  
> 🧠 **Don’t overthink; use common sense** — but verify like you’re paid by the log entry.  
> 🔑 **Password is not a password** — yes, someone already tried it. Successfully.

### Proxmox Cloud-Init Template Generator ###

Script documentation is a work in progress. 

#### Clone the Repo #### 
```
git clone https://github.com/meabert/Proxmox-Bulk-Deploy/ && 
```
##### Test out the script #####
```
c
