# ArchLinux Installer Script
[![GitHub Super-Linter](https://github.com/limaon/ArchInstaller/workflows/Lint%20Code%20Base/badge.svg)](https://github.com/marketplace/actions/super-linter)

This README outlines the process for installing and configuring a fully-functional Arch Linux desktop system. It includes installing a desktop environment, all necessary support packages for networking, Bluetooth, audio, printing and more. Additionally, it covers setting up preferred applications and utilities. The shell scripts in this repository allow the entire installation and configuration process to be automated. Users can run a single script to deploy an Arch system with their chosen desktop, packages and programs pre-installed and ready to use.

---
## Create Arch ISO or Use Image

Download ArchISO from <https://archlinux.org/download/> and put on a USB drive with [Etcher](https://www.balena.io/etcher/), [Ventoy](https://www.ventoy.net/en/index.html), or [Rufus](https://rufus.ie/en/)


- New single command quick launch

```
bash <(curl -L tinyurl.com/4b3jcbpd)
```


## Boot Arch ISO

From initial Prompt type the following commands:

```
pacman -Sy git
git clone --depth=1 https://github.com/limaon/ArchInstaller.git
cd ArchInstaller
./archinstall.sh
```

### System Description
This is completely automated arch install. It includes prompts to select your desired desktop environment, window manager, AUR helper, and whether to do a full or minimal install. The KDE desktop environment on arch includes all the packages I use on a daily basis, as well as some customizations.

## Troubleshooting

__[Arch Linux RickEllis Installation Guide](https://github.com/rickellis/Arch-Linux-Install-Guide)__

__[Arch Linux Wiki Installation Guide](https://wiki.archlinux.org/title/Installation_guide)__

The main script will generate .log files for every script that is run as part of the installation process. These log files contain the terminal output so you can review any warnings or errors that occurred during installation and aid in troubleshooting.
### No Wifi

You can check if the WiFi is blocked by running `rfkill list`.
If it says **Soft blocked: yes**, then run `rfkill unblock wifi`

After unblocking the WiFi, you can connect to it. Go through these 5 steps:

#1: Run `iwctl`

#2: Run `device list`, and find your device name.

#3: Run `station [device name] scan`

#4: Run `station [device name] get-networks`

#5: Find your network, and run `station [device name] connect [network name]`, enter your password and run `exit`. You can test if you have internet connection by running `ping google.com`, and then Press Ctrl and C to stop the ping test.

## Reporting Issues

An issue is easier to resolve if it contains a few important pieces of information.
1. Chosen configuration from /configs/setup.conf (DONT INCLUDE PASSWORDS)
1. Errors seen in .log files
1. What commit/branch you used
1. Where you were installing (VMWare, Virtualbox, Virt-Manager, Baremetal, etc)
    1. If a VM, what was the configuration used.

## Credits

- Original packages script was a post install cleanup script called ArchMatic located here: https://github.com/rickellis/ArchMatic

- This repository was originally created and maintained by Chris Titus, located at https://github.com/ChrisTitusTech/ArchTitus.

- Thank you to Chris for developing the initial automated Arch Linux installation scripts and tutorials that served as a foundation for this project.
