# Installer Helper# 

Contains the functions used to facilitate the installer

# Functions
* [exit_on_error()](#exit_on_error)
* [show_logo()](#show_logo)
* [function multiselect {](#function-multiselect-)
* [sequence()](#sequence)
* [set_option()](#set_option)
* [source_file()](#source_file)
* [end_script()](#end_script)


## exit_on_error()## 

Exits script if previous command fails

### Output on stdout### 

* Output routed to install.log* 

### Output on stderr### 

* # @stderror Output routed to install.log* 

### Arguments### 

* **$1** (string): Exit code of previous command* 

### Arguments### 

* **$2** (string): Previous command* 

## show_logo()## 

display archinstaller logo

_Function has no arguments.___

## function multiselect {## 

Select multiple options

_Function has no arguments.___

## sequence()## 

Sequence to call scripts

_Function has no arguments.___

## set_option()## 

set options in setup.conf

### Arguments### 

* **$1** (string): Configuration variable.* 

### Arguments### 

* **$2** (string): Configuration value.* 

## source_file()## 

Sources file to be used by the script

### Arguments### 

* **$1** (File): to source* 

## end_script()## 

Copy logs to installed system and exit script

_Function has no arguments.___


