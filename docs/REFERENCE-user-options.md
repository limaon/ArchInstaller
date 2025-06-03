# User Options# 

User configuration functions to set variables to be used during installation

# Functions
* [set_password()](#set_password)
* [user_info()](#user_info)
* [install_type()](#install_type)
* [aur_helper()](#aur_helper)
* [desktop_environment()](#desktop_environment)
* [disk_select()](#disk_select)
* [filesystem()](#filesystem)
* [set_btrfs()](#set_btrfs)
* [timezone()](#timezone)
* [locale_selection()](#locale_selection)
* [keymap()](#keymap)
* [show_configurations()](#show_configurations)


## set_password()## 

Read and verify user password before setting

### Output on stdout### 

* Output routed to install.log* 

### Output on stderr### 

* # @stderror Output routed to install.log* 

_Function has no arguments.___

## user_info()## 

Gather username, real name, and password to be used for installation.

_Function has no arguments.___

## install_type()## 

Choose whether to do full or minimal installation.

_Function has no arguments.___

## aur_helper()## 

Choose AUR helper.

_Function has no arguments.___

## desktop_environment()## 

Choose Desktop Environment

_Function has no arguments.___

## disk_select()## 

Disk selection for drive to be used with installation.

_Function has no arguments.___

## filesystem()## 

This function will handle file systems. At this movement we are handling only
btrfs and ext4. Others will be added in future.

_Function has no arguments.___

## set_btrfs()## 

Set btrfs subvolumes to be used during install

_Function has no arguments.___

## timezone()## 

Detects and sets timezone.

_Function has no arguments.___

## locale_selection()## 

Set system language (locale)

_Function has no arguments.___

## keymap()## 

Set user's keyboard mapping.

_Function has no arguments.___

## show_configurations()## 

Show all configurations set during the setup and allow user to redo any step.

_Function has no arguments.___


