#!/bin/bash
set -e

# MIT License
#
# Copyright (c) 2020 Kasper Stad
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

#export CLOUDIMG="https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img"
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Script Basename
BASENAME=$(basename $0)

# Help meassage
function get_help()
{
    echo
    echo "Usage: $BASENAME <parameters> ..."
    echo 
    echo "Parameters:"
    echo "    -h, --help              Show this help message."
    echo "    -n, --name              (required) Name of the VM without spaces, dots and other ambiguous characters"
    echo "                            If longer than 15 characters, the name will automatically be shortned"
    echo "    -o, --ostype            Operating System (default: ubuntu20)"
    echo "                            valid options are: ubuntu18, ubuntu20, debian10"
    echo "    -c, --cores             CPU Cores that will be assigned to the VM (default: 1)"
    echo "    -m, --memory            Memory that will be allocated to the VM in MB (default: 1024)"
    echo "    -s, --storage           Storage where the VM will be placed (default: local-lvm)"
    echo "    -d, --domain            Domainname of this VM (eg. example.com)"
    echo "    -i, --ip-address        (required) IP Address of this VM in CIDR format (eg. 192.168.1.2/24)"
    echo "    --network-bridge        Network Bridge that the VM should be attached to (default: vmbr0)"
    echo "    --disk-size             Size of the VM disk in GB (default: 20)"
    echo "    --disk-format           Format of the disk, leave out if not using a supported storage (default: raw)"
    echo "    --dns-server            DNS Server (default: 8.8.8.8)"
    echo "    --gateway               Default Gateway, if undefined, script will set it to the specified IP with the fouth octet as .1"
    echo "                            (eg. default gateway will be 192.168.1.1)"
    echo "    --ssh-keyfile           (required) SSH Keys used for ssh'ing in using the user \"ubuntu\", multiple ssh-keys allowed in file (one key on each line)"
    echo "    --no-start-created      Don't start the VM after it's created"
    echo
    exit 1
}

# This script needs root permissions to run, check that
if [ "$EUID" -ne 0 ]; then
    echo "[$BASENAME] Error: You must run this script as root!"
    exit 1
fi

# Get Help if you don't specify any arguments...
if [ ${#} -eq 0 ]; then
    get_help
fi

# Parse all parameters
while [ ${#} -gt 0 ]; do
    case "${1}" in
        -h|--help)
            get_help
            ;;
        -n|--name)
            VM_NAME="$2"
            if [[ $VM_NAME == *['!'@#\$%^\&*()\_+\']* ]];then
                echo "[$BASENAME] specified hostname is invalid"
                exit 1
            fi
            shift
            shift
            ;;
        -o|--ostype)
            case "$2" in
                ubuntu18)
                    VM_OSTYPE="ubuntu18"
                    ;;
                ubuntu20)
                    VM_OSTYPE="ubuntu20"
                    ;;
                debian10)
                    VM_OSTYPE="debian10"
                    ;;
            esac
            shift
            shift
            ;;
        -c|--cores)
            VM_CORES=$2
            shift
            shift
            ;;
        -m|--memory)
            VM_MEMORY=$2
            shift
            shift
            ;;
        -s|--storage)
            VM_STORAGE="$2"
            shift
            shift
            ;;
        -d|--domain)
            VM_DOMAIN="$2"
            shift
            shift
            ;;
        -i|--ip-address)
            VM_IP_ADDRESS="$2"
            shift
            shift
            ;;
        --network-bridge)
            VM_NET_BRIDGE="$2"
            ;;
        --disk-size)
            VM_DISK_SIZE="$2"
            shift
            shift
            ;;
        --disk-format)
            VM_DISK_FORMAT="$2"
            shift
            shift
            ;;
        --dns-server)
            VM_DNS_SERVER="$2"
            shift
            shift
            ;;
        --gateway)
            VM_GATEWAY="$2"
            shift
            shift
            ;;
        --cloudimg-template-path)
            VM_CLOUDIMG_TEMPLATEPATH="$2"
            shift
            shift
            ;;
        --ssh-keyfile)
            VM_SSH_KEYFILE="$2"
            shift
            shift
            ;;
        --no-start-created)
            VM_NO_START_CREATED=1
            ;;
        *)
            get_help
            ;;
    esac
done

# Default values if they wasn't defined as parameters
VM_CORES=${VM_CORES:-1}
VM_CLOUDIMG_TEMPLATEPATH=${VM_CLOUDIMG_TEMPLATEPATH:-"/var/lib/vz"}
VM_MEMORY=${VM_MEMORY:-1024}
VM_STORAGE=${VM_STORAGE:-"local-lvm"}
VM_DOMAIN=${VM_DOMAIN:-"localdomain"}
VM_NET_BRIDGE=${VM_NET_BRIDGE:-"vmbr0"}
VM_OSTYPE=${VM_OSTYPE:-"ubuntu20"}
VM_DISK_SIZE=${VM_DISK_SIZE:-20}
VM_DISK_FORMAT=${VM_DISK_FORMAT:-"raw"}
VM_DNS_SERVER=${VM_DNS_SERVER:-"8.8.8.8"}

# Get Help if you don't specify required parameters (yes I know I'm a little demanding ;) )...
if [[ -z $VM_NAME || -z $VM_IP_ADDRESS || -z $VM_SSH_KEYFILE ]]; then
    get_help
fi

VM_CLOUDIMG_TEMPLATEPATH="${VM_CLOUDIMG_TEMPLATEPATH}/template"

echo $VM_OSTYPE

case "${VM_OSTYPE}" in
    ubuntu18)
        VM_CLOUDIMG_MD5SUMS="https://cloud-images.ubuntu.com/bionic/current/MD5SUMS"
        VM_CLOUDIMG_URL="https://cloud-images.ubuntu.com/bionic/current/bionic-server-cloudimg-amd64.img"
        VM_CLOUDIMG_PATH="${VM_CLOUDIMG_TEMPLATEPATH}/$(basename $VM_CLOUDIMG_URL)"
        ;;
    ubuntu20)
        VM_CLOUDIMG_MD5SUMS="https://cloud-images.ubuntu.com/focal/current/MD5SUMS"
        VM_CLOUDIMG_URL="https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img"
        VM_CLOUDIMG_PATH="${VM_CLOUDIMG_TEMPLATEPATH}/$(basename $VM_CLOUDIMG_URL)"
        ;;
    debian10)
        VM_CLOUDIMG_MD5SUMS="https://cdimage.debian.org/cdimage/openstack/current/MD5SUMS"
        VM_CLOUDIMG_URL="https://cdimage.debian.org/cdimage/openstack/current-10/debian-10-openstack-amd64.qcow2"
        VM_CLOUDIMG_PATH="${VM_CLOUDIMG_TEMPLATEPATH}/$(basename $VM_CLOUDIMG_URL)"
        ;;
esac

# Fetch the next available VM ID
VMID=$(pvesh get /cluster/nextid)

if [ -f "${VM_CLOUDIMG_PATH}.md5sum" ]; then
    wget -o /dev/null -O "${VM_CLOUDIMG_TEMPLATEPATH}/MD5SUMS" ${VM_CLOUDIMG_MD5SUMS}
    grep "$(basename $VM_CLOUDIMG_URL)" "${VM_CLOUDIMG_TEMPLATEPATH}/MD5SUMS" > "${VM_CLOUDIMG_PATH}.md5sum.new"
    if [ "$(cat ${VM_CLOUDIMG_PATH}.md5sum)" -ne "$(cat ${VM_CLOUDIMG_PATH}.md5sum.new)" ]; then
        echo "[$BASENAME]: newer image available, downloading"
        wget --show-progress -o /dev/null -O $VM_CLOUDIMG_PATH $VM_CLOUDIMG_URL
        mv "${VM_CLOUDIMG_PATH}.md5sum.new" "${VM_CLOUDIMG_PATH}.md5sum"
    fi
else
    echo "[$BASENAME]: newer image available, downloading"
    wget -o /dev/null -O "${VM_CLOUDIMG_TEMPLATEPATH}/MD5SUMS" ${VM_CLOUDIMG_MD5SUMS}
    grep "$(basename $VM_CLOUDIMG_URL)" "${VM_CLOUDIMG_TEMPLATEPATH}/MD5SUMS" > "${VM_CLOUDIMG_PATH}.md5sum"
    wget --show-progress -o /dev/null -O $VM_CLOUDIMG_PATH $VM_CLOUDIMG_URL
fi

if [ -f "${VM_CLOUDIMG_TEMPLATEPATH}/MD5SUMS" ]; then
    rm -f "${VM_CLOUDIMG_TEMPLATEPATH}/MD5SUMS"
fi

exit


# Temporary variables for generating the image
#tempCloudImg="/tmp/$(basename $CLOUDIMG)"


# Download the image
#wget --show-progress -o /dev/null -O $tempCloudImg $CLOUDIMG

# Generate additional cloud-init config to install qemu-guest-agent

tempCloudConfFile="/tmp/50_guest-agent.cfg"
cat > $tempCloudConfFile << EOF
packages:
  - qemu-guest-agent
runcmd:
  - systemctl enable qemu-guest-agent
  - systemctl restart qemu-guest-agent
EOF

# Copy the new cloud-init
virt-copy-in -a $tempCloudImg $tempCloudConfFile /etc/cloud/cloud.cfg.d

# Create the new VM
qm create $VMID --name $VM_NAME --cores $VM_CORES --memory $VM_MEMORY -ostype l26 --agent 1

# Import the image to the storage and attach it
qm importdisk $VMID $tempCloudImg $VM_STORAGE
qm set $VMID --scsihw virtio-scsi-pci --scsi0 $VM_STORAGE:vm-$VMID-disk-0,discard=on

# Resize the imported disk
qm resize $VMID scsi0 ${VM_DISK_SIZE}G

# Set the default boot disk to be the newly imported disk
qm set $VMID --boot c --bootdisk scsi0

# Add a cloud-init drive
qm set $VMID --ide2 $VM_STORAGE:cloudinit

# Add the SSH Keys to the server
qm set $VMID --sshkey $VM_SSH_KEYFILE

# Set the VM to use serial0 as the default vga device
qm set $VMID --serial0 socket --vga serial0

# Attach network interface to a bridge
qm set $VMID --net0 virtio,bridge=$VM_NET_BRIDGE

# If no default gateway is defined, we're creating one
if [ -z "${VM_GATEWAY}" ]; then
    VM_GATEWAY="$(echo ${VM_IP_ADDRESS} | cut -d '.' -f 1,2,3).1"
fi

# Setup the network, DNS server and domain
qm set $VMID --ipconfig0 ip=$VM_IP_ADDRESS,gw=$VM_GATEWAY
qm set $VMID --nameserver $VM_DNS_SERVER
qm set $VMID --searchdomain $VM_DOMAIN

# if --no-start-created wasn't spedified, start the VM after it's created
if [ -z $VM_NO_START_CREATED ]; then
    qm start $VMID
fi

# remove the downloaded image
rm -f $tempCloudImg
rm -f $tempCloudConfFile
