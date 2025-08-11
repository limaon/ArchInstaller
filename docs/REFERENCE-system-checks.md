# System Checks

Contains the functions used to perform various checks to safely run program

# Functions
* [root_check()](#root_check)
* [arch_check()](#arch_check)
* [pacman_check()](#pacman_check)
* [docker_check()](#docker_check)
* [mount_check()](#mount_check)
* [background_checks()](#background_checks)


## root_check()

Check if script is run with root

### Output on stdout

* Output routed to install.log

### Output on stderr

* # @stderror Output routed to install.log

_Function has no arguments._

## arch_check()

Check if script is being ran in an arch linux distro

_Function has no arguments._

## pacman_check()

Checks if pacman lock exists

_Function has no arguments._

## docker_check()

Checks if script run inside docker container

_Function has no arguments._

## mount_check()

Checks if drive is mounted

_Function has no arguments._

## background_checks()

Run all checks necessary before running script

_Function has no arguments._


