# System Config# 

Contains the functions used to modify the system

# Functions
* [mirrorlist_update()](#mirrorlist_update)
* [format_disk()](#format_disk)
* [create_filesystems()](#create_filesystems)
* [do_btrfs()](#do_btrfs)
* [low_memory_config()](#low_memory_config)
* [cpu_config()](#cpu_config)
* [locale_config()](#locale_config)
* [extra_repos()](#extra_repos)
* [add_user()](#add_user)
* [grub_config()](#grub_config)
* [display_manager()](#display_manager)
* [snapper_config()](#snapper_config)
* [configure_tlp()](#configure_tlp)
* [plymouth_config()](#plymouth_config)


## mirrorlist_update()## 

Update mirrorlist to improve download speeds using rankmirrors if reflector is unavailable

### Output on stdout### 

* Output routed to install.log* 

### Output on stderr### 

* # @stderror Output routed to install.log* 

_Function has no arguments.___

## format_disk()## 

Format disk before creating filesystem(s)

_Function has no arguments.___

## create_filesystems()## 

Create the filesystem on the drive selected for installation

_Function has no arguments.___

## do_btrfs()## 

Perform the btrfs filesystem configuration

_Function has no arguments.___

## low_memory_config()## 

Configure zram for systems with low memory

_Function has no arguments.___

## cpu_config()## 

Configures makepkg settings dependent on cpu cores

_Function has no arguments.___

## locale_config()## 

Set locale, timezone, keymap, and vconsole configuration

_Function has no arguments.___

## extra_repos()## 

Adds multilib and chaotic-aur repo to get precompiled aur packages

_Function has no arguments.___

## add_user()## 

Adds user that was setup prior to installation

_Function has no arguments.___

## grub_config()## 

Configure GRUB and set a wallpaper (if not SERVER installation)

_Function has no arguments.___

## display_manager()## 

Install and enable display manager depending on desktop environment chosen

_Function has no arguments.___

## snapper_config()## 

Configure snapper default setup

_Function has no arguments.___

## configure_tlp()## 

Configures TLP for power management on laptops.

_Function has no arguments.___

## plymouth_config()## 

Install plymouth splash

_Function has no arguments.___


