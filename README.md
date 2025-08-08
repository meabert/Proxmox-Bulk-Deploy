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

