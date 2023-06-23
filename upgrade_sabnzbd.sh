#!/bin/bash

# This script will upgrade the "generic linux" version of sabnzbd

# Requires bsdtar, (Ubuntu) sudo apt-get install libarchive-tools
# I use bsdtar because tar would sometimes fail to overwrite files. I gave up lookiing as to why and just use the alternative.

install_path=/opt/sabnzbd

# Get latest version number of sabnzbd from github
tag=$(curl --silent "https://api.github.com/repos/sabnzbd/sabnzbd/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

# Get current installed version
file="./version" && version=$(cat "$file")

# Compare current installed to latest on website.  If match, exit script.
if [ "$version" = "$tag" ]; then
    echo "You're using the latest version at $tag"
    return 0
fi

# Download latest version
wget https://github.com/sabnzbd/sabnzbd/archive/"$tag".tar.gz

# Stop sabnzbd service, and extract new over old
sudo systemctl stop sabnzbd.service
bsdtar --strip-components=1 -xf "$tag".tar.gz

# Delete downloaded file
rm "$tag".tar.gz

# Make sure the required python modules are installed in my virtual env
FILE=$install_path/requirements.txt
if [ -f "$FILE" ]; then
    $install_path/venv/bin/python3 -m pip install --upgrade pip
    $install_path/venv/bin/python3 -m pip install -r requirements.txt -U
fi

# Start the sabnzbd service
sudo systemctl start sabnzbd.service

# Modify version file, announce to user the app has been updated.
echo "$tag" > version
echo "Upgraded from $version to $tag." fi
