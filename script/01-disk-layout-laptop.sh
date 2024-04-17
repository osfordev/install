#!/bin/bash
#

set -e


ROOT_UID=0   # Only users with $UID 0 have root privileges.
E_NOTROOT=87 # Non-root exit error.


# Prevent the execution of the script if the user has no root privileges
if [ "${UID:-$(id -u)}" -ne "${ROOT_UID}" ]; then
	echo 'Error: root privileges are needed to run this script' >&2
	exit ${E_NOTROOT}
fi

if [ -z "${DEFAULT_DISK_PASS_1}" ]; then
	echo "DEFAULT_DISK_PASS_1 is not defined" >&2
	exit 1
fi
if [ -z "${DEFAULT_DISK_PASS_2}" ]; then
	echo "DEFAULT_DISK_PASS_2 is not defined" >&2
	exit 1
fi

if [ -z "${DRIVE}" ]; then
	echo "DRIVE is not defined" >&2
	exit 1
fi

# Get product name
#SKU_NUMBER=$(dmidecode -s system-sku-number)


# DISKS=($(lsblk --nodeps --paths --include=8 --noheadings --output=NAME))
# for index in ${!DISKS[*]}; do
# 	let "number=index+1"
# 	printf "%4d: %s\n" "$number" "${DISKS[$index]}"
# done

# DISK_NUMBER=0
# while [ "${DISK_NUMBER}" -eq 0 ]; do
# 	read -p "Choose disk number: " DISK_NUMBER
# 	let "DISK_NUMBER=DISK_NUMBER+0"
# 	let "DISK_NUMBER=DISK_NUMBER*1"
# 	echo "${DISK_NUMBER}"
# done

# # Find internal drive
# fdisk -l /dev/sd[a-z]
# fdisk -l /dev/nvme*

#DRIVE=/dev/sda

# EFI System /dev/sda1 256M
# Linux LVM  /dev/sda2 100%FREE
sfdisk --wipe always --label gpt "${DRIVE}" <<EOF
,256M,C12A7328-F81F-11D2-BA4B-00A0C93EC93B
,,E6D6D379-F507-44C2-A23C-238F2A3DF928
EOF

pvcreate "${DRIVE}2"
vgcreate vg0 "${DRIVE}2"

lvcreate --name images --size 12G vg0
lvcreate --name system --size 36G vg0
lvcreate --name luks-swap  --size $(grep MemTotal /proc/meminfo | awk '{print $2}')K vg0
lvcreate --name luks-registry --size 128M vg0
lvcreate --name luks-home --size 48G vg0

echo -n "${DEFAULT_DISK_PASS_1}" | cryptsetup luksFormat /dev/vg0/luks-home
echo -n "${DEFAULT_DISK_PASS_1}" | cryptsetup luksFormat /dev/vg0/luks-registry
echo -n "${DEFAULT_DISK_PASS_1}" | cryptsetup luksFormat /dev/vg0/luks-swap

printf '%s\n' "${DEFAULT_DISK_PASS_1}" "${DEFAULT_DISK_PASS_2}" "${DEFAULT_DISK_PASS_2}" | cryptsetup luksAddKey /dev/vg0/luks-home
printf '%s\n' "${DEFAULT_DISK_PASS_1}" "${DEFAULT_DISK_PASS_2}" "${DEFAULT_DISK_PASS_2}" | cryptsetup luksAddKey /dev/vg0/luks-registry
printf '%s\n' "${DEFAULT_DISK_PASS_1}" "${DEFAULT_DISK_PASS_2}" "${DEFAULT_DISK_PASS_2}" | cryptsetup luksAddKey /dev/vg0/luks-swap

echo -n "${DEFAULT_DISK_PASS_1}" | cryptsetup luksOpen /dev/vg0/luks-home uncrypted-home
echo -n "${DEFAULT_DISK_PASS_1}" | cryptsetup luksOpen /dev/vg0/luks-registry uncrypted-registry
echo -n "${DEFAULT_DISK_PASS_1}" | cryptsetup luksOpen /dev/vg0/luks-swap uncrypted-swap


mkfs.vfat -F32 -n boot "${DRIVE}1"
mkswap -L swap /dev/mapper/uncrypted-swap
mkfs.ext4 -m 0 -L registry /dev/mapper/uncrypted-registry
mkfs.ext4 -m 0 -L home /dev/mapper/uncrypted-home

mkfs.ext4 -L system /dev/vg0/system
mkfs.ext4 -L images -N 3072 /dev/vg0/images

cryptsetup luksClose /dev/mapper/uncrypted-home
cryptsetup luksClose /dev/mapper/uncrypted-registry
cryptsetup luksClose /dev/mapper/uncrypted-swap

vgchange --activate n
