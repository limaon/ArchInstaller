#!/usr/bin/env bash
#github-action genshdoc
#
# @file Preinstall
# @brief Contains the steps necessary to configure and pacstrap the install to selected drive. 


echo -ne "
-------------------------------------------------------------------------
                    Automated Arch Linux Installer
-------------------------------------------------------------------------

Setting up mirrors for optimal download
"
source $CONFIGS_DIR/setup.conf
iso=$(curl -4 ifconfig.co/country-iso)
timedatectl set-ntp true
mount -o remount,size=2G /run/archiso/cowspace # Increase archiso disk space
pacman -Sy --noconfirm archlinux-keyring #update keyrings to latest to prevent packages failing to install
pacman -S --noconfirm --needed pacman-contrib terminus-font
setfont ter-v22b
# sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf

# Optimize commands for pacman.conf
sed -i -e 's/^#ParallelDownloads/ParallelDownloads/' \
       -e 's/^#VerbosePkgLists/VerbosePkgLists/' \
       -e '/\[multilib\]/,/Include/s/^#//' \
       -e 's/^#Color/Color/' /etc/pacman.conf

pacman -Sy --noconfirm --needed reflector rsync grub
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup

echo -ne "
-------------------------------------------------------------------------
                    Setting up $iso mirrors for faster downloads
-------------------------------------------------------------------------
"
# reflector -a 48 -c $iso -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist
# reflector --verbose --country $iso --latest 20 --sort rate --save /etc/pacman.d/mirrorlist
reflector --verbose -a 48 -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist
mkdir -p /mnt/sysArch &>/dev/null # Hiding error message if any
echo -ne "
-------------------------------------------------------------------------
                    Installing Prerequisites
-------------------------------------------------------------------------
"
pacman -S --noconfirm --needed gptfdisk btrfs-progs glibc
echo -ne "
-------------------------------------------------------------------------
                    Formating Disk
-------------------------------------------------------------------------
"
# make sure everything is unmounted before we start
if mountpoint -q /mnt/sysArch; then
    echo "/mnt/sysArch is mounted."
    umount --lazy -A --recursive /mnt/sysArch

    # Check the exit status of umount command
	[ $? -eq 0 ] && echo "Unmount successful." || echo "Unmount failed."
else
    echo "/mnt/sysArch is not mounted (continue installation)."
fi


# disk prep
sgdisk -Z ${DISK} # zap all on disk
sgdisk -a 2048 -o ${DISK} # new gpt disk 2048 alignment

# create partitions
sgdisk -n 1::+1M --typecode=1:ef02 --change-name=1:'BIOSBOOT' ${DISK} # partition 1 (BIOS Boot Partition)
sgdisk -n 2::+300M --typecode=2:ef00 --change-name=2:'EFIBOOT' ${DISK} # partition 2 (UEFI Boot Partition)
sgdisk -n 3::-0 --typecode=3:8300 --change-name=3:'ROOT' ${DISK} # partition 3 (Root), default start, remaining
if [[ ! -d "/sys/firmware/efi" ]]; then # Checking for bios system
    sgdisk -A 1:set:2 ${DISK}
fi
partprobe ${DISK} # reread partition table to ensure it is correct

# make filesystems
echo -ne "
-------------------------------------------------------------------------
                    Creating Filesystems
-------------------------------------------------------------------------
"
# @description Creates the btrfs subvolumes. 
createsubvolumes () {
    btrfs subvolume create /mnt/sysArch/@
    btrfs subvolume create /mnt/sysArch/@home
    btrfs subvolume create /mnt/sysArch/@var
    btrfs subvolume create /mnt/sysArch/@tmp
    btrfs subvolume create /mnt/sysArch/@.snapshots
}

# @description Mount all btrfs subvolumes after root has been mounted.
mountallsubvol () {
    mount -o ${MOUNT_OPTIONS},subvol=@home ${partition3} /mnt/sysArch/home
    mount -o ${MOUNT_OPTIONS},subvol=@tmp ${partition3} /mnt/sysArch/tmp
    mount -o ${MOUNT_OPTIONS},subvol=@var ${partition3} /mnt/sysArch/var
    mount -o ${MOUNT_OPTIONS},subvol=@.snapshots ${partition3} /mnt/sysArch/.snapshots
}

# @description BTRFS subvolulme creation and mounting. 
subvolumesetup () {
	# create nonroot subvolumes
	createsubvolumes

	# unmount root to remount with subvolume
	umount /mnt/sysArch

	# mount @ subvolume
	mount -o ${MOUNT_OPTIONS},subvol=@ ${partition3} /mnt/sysArch

	# make directories home, .snapshots, var, tmp
	mkdir -p /mnt/sysArch/{home,var,tmp,.snapshots}

	# mount subvolumes
	mountallsubvol
}

if [[ "${DISK}" =~ "nvme" ]]; then
    partition2=${DISK}p2
    partition3=${DISK}p3
else
    partition2=${DISK}2
    partition3=${DISK}3
fi

if [[ "${FS}" == "btrfs" ]]; then
    mkfs.vfat -F32 -n "EFIBOOT" ${partition2}
    mkfs.btrfs -L ROOT ${partition3} -f
    mount -t btrfs ${partition3} /mnt/sysArch
    subvolumesetup
elif [[ "${FS}" == "ext4" ]]; then
    mkfs.vfat -F32 -n "EFIBOOT" ${partition2}
    mkfs.ext4 -L ROOT ${partition3}
    mount -t ext4 ${partition3} /mnt/sysArch
elif [[ "${FS}" == "luks" ]]; then
    mkfs.vfat -F32 -n "EFIBOOT" ${partition2}

	# enter luks password to cryptsetup and format root partition
    echo -n "${LUKS_PASSWORD}" | cryptsetup -y -v luksFormat ${partition3} -

	# open luks container and ROOT will be place holder
    echo -n "${LUKS_PASSWORD}" | cryptsetup open ${partition3} ROOT -

	# now format that container
    mkfs.btrfs -L ROOT ${partition3}

	# create subvolumes for btrfs
    mount -t btrfs ${partition3} /mnt/sysArch
    subvolumesetup

	# store uuid of encrypted partition for grub
    echo ENCRYPTED_PARTITION_UUID=$(blkid -s UUID -o value ${partition3}) >> $CONFIGS_DIR/setup.conf
fi

# mount target
mkdir -p /mnt/sysArch/boot/efi
mount -t vfat -L EFIBOOT /mnt/sysArch/boot/

if ! grep -qs '/mnt/sysArch' /proc/mounts; then
    echo "Drive is not mounted can not continue"
    echo "Rebooting in 3 Seconds ..." && sleep 1
    echo "Rebooting in 2 Seconds ..." && sleep 1
    echo "Rebooting in 1 Second ..." && sleep 1
    reboot now
fi
echo -ne "
-------------------------------------------------------------------------
                    Arch Install on Main Drive
-------------------------------------------------------------------------
"
# Copy pacman.conf from host to target
pacstrap -P -K /mnt/sysArch base base-devel linux-lts linux-firmware neovim sudo archlinux-keyring wget curl libnewt --noconfirm --needed
echo "keyserver hkp://keyserver.ubuntu.com" >> /mnt/sysArch/etc/pacman.d/gnupg/gpg.conf
cp -R ${SCRIPT_DIR} /mnt/sysArch/root/ArchInstaller
cp /etc/pacman.d/mirrorlist /mnt/sysArch/etc/pacman.d/mirrorlist

genfstab -L /mnt/sysArch >> /mnt/sysArch/etc/fstab
echo " 
  Generated /etc/fstab:
"
cat /mnt/sysArch/etc/fstab
echo -ne "
-------------------------------------------------------------------------
                    GRUB BIOS Bootloader Install & Check
-------------------------------------------------------------------------
"
if [[ ! -d "/sys/firmware/efi" ]]; then
    grub-install --boot-directory=/mnt/sysArch/boot ${DISK}
else
    pacstrap /mnt/sysArch efibootmgr --noconfirm --needed
fi
echo -ne "
-------------------------------------------------------------------------
                    Checking for low memory systems <8G
-------------------------------------------------------------------------
"
TOTAL_MEM=$(cat /proc/meminfo | grep -i 'memtotal' | grep -o '[[:digit:]]*')
if [[  $TOTAL_MEM -lt 8000000 ]]; then
    # Put swap into the actual system, not into RAM disk, otherwise there is no point in it, it'll cache RAM into RAM. So, /mnt/sysArch/ everything.
    mkdir -p /mnt/sysArch/opt/swap # make a dir that we can apply NOCOW to to make it btrfs-friendly.
    chattr +C /mnt/sysArch/opt/swap # apply NOCOW, btrfs needs that.
    dd if=/dev/zero of=/mnt/sysArch/opt/swap/swapfile bs=1M count=2048 status=progress
    chmod 600 /mnt/sysArch/opt/swap/swapfile # set permissions.
    chown root /mnt/sysArch/opt/swap/swapfile
    mkswap /mnt/sysArch/opt/swap/swapfile
    swapon /mnt/sysArch/opt/swap/swapfile
    # The line below is written to /mnt/sysArch/ but doesn't contain /mnt/sysArch/, since it's just / for the system itself.
    echo "/opt/swap/swapfile	none	swap	sw	0	0" >> /mnt/sysArch/etc/fstab # Add swap to fstab, so it KEEPS working after installation.
fi
echo -ne "
-------------------------------------------------------------------------
                    SYSTEM READY FOR 1-setup.sh
-------------------------------------------------------------------------
"
