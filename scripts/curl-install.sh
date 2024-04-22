#!/bin/bash

# Checking if is running in Repo Folder
if [[ "$(basename "$(pwd)" | tr '[:upper:]' '[:lower:]')" =~ ^scripts$ ]]; then
    echo "You are running this in ArchInstaller Folder."
    echo "Please use ./archtitus.sh instead"
    exit
fi

# Installing git

echo "Installing git."
pacman -Sy --noconfirm --needed git glibc

echo "Cloning the ArchInstaller Project"
git clone https://github.com/limaon/ArchInstaller.git

echo "Executing ArchInstaller Script"

cd $HOME/ArchInstaller

exec ./archtitus.sh
