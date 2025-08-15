

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
- [x] Addititional OS choices (VIA --image flag)
- [ ] Add automated image download to eliminate file management
- [ ] Killswitch script - shutdown, delete, housekeeping in one script

This is desinged to be simple press and go script that is system agnostic
with minimal to no additional configuration required compared to other
tools like Ansible, Packer or Terraform.

> [!TIP]
> For best performance and ease of use, it is recommended to run these scripts
> locally and stream ISO/Images from offload such as a NAS, SAN, or similar
> Deploying many VM's at the same time will place significant strain on the
> network and drives. One can greatly improve the performance of the deployment
> if there are multiple nodes or drives to store images on exclusively.

This tool enables one to easily spin up 20+ logical VM's in a matter of minutes. 
This is of course assuming requirements are met for hardware, network, storage, 
staff and the underlying infrastructure to support all of it. 

> [!WARNING]
> For ease of use all scripts will use default password authentication, the
> password will be stored as hashed value in a file after creation for
> record-keeping. Make sure you .gitignore this file since it will have
> sensitive information! When ready to make anything public facing it MUST
> be switched to key-authentication at the minimum for production.

My background is in the Payment Services Industry - I bring my experience in
PCI-DSS Compliance and will do my best to apply this where appropriate. With
that said this tool comes with zero warranty or liability, check the script
before you run the code, check the drive before you nuke it and think before
you execute.

> [!CAUTION] Operator’s Oath**  
> 🚫 **Obscurity is not security** — bots don't care you put it on port 44523.”  
> 🔓 **Open ports are an open invitation** — and the guests don’t bring snacks.  
> 📊 **Know your threat level** — ignorance is a privilege your firewall can’t afford.  
> 🧠 **Don’t overthink; use common sense** — but verify like you’re paid by the log entry.  
> 🔑 **Password is not a password** — yes, someone already tried it. Successfully.

### Proxmox Cloud-Init Template Generator ###

Script documentation is a work in progress. 

#### Clone the Repo #### 
```
git clone https://github.com/meabert/Proxmox-Bulk-Deploy/ && cd Proxmox-Bulk-Deploy
```
##### Test out the script #####
Make the scripts executable
```
chmod +x build.sh create.sh storage-selector.py
```
Run the template maker with the --image flag, use this to tell the script where
you keep your image
```
./create.sh --image /myimages/debian-13.qcow
```
The script will prompt you to pick an ID number for the template.
Pick the disk you want the template on
Provide username for cloudinit
Provide password for cloudinit
Template specific values saved to .template.env
