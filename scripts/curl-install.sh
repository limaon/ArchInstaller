#!/bin/bash

# Checking if is running in Repo Folder
if [[ "$(basename "$(pwd)" | tr '[:upper:]' '[:lower:]')" =~ ^scripts$ ]]; then
    echo "You are running this in ArchInstaller Folder."
    echo "Please use ./archinstall.sh instead"
    exit
fi
setfont ter-v22b

# Installing git
echo "Installing git."
pacman -Sy --noconfirm --needed git glibc

echo "Cloning the Project"
git clone --depth=1 https://github.com/limaon/ArchInstaller

echo -e "\nExecuting Script"

cd $HOME/ArchInstaller

exec ./archinstall.sh
