#!/bin/bash
# This script will upgrade the "Generic Linux" version of Jellyfin, and upgrade the portable jellyfin-ffmpeg portable if requested.

set -e  # Exit on error

# Uncomment the ffmpeg line if you do NOT want to install and update ffmpeg portable.
install_path=/opt/jellyfin

mkdir -p $install_path
cd $install_path

mkdir -p $install_path/jellyfin

# if not exist, create version file. You can delete the version file to force upgrade
[ ! -f $install_path/version ] && \
touch $install_path/version && \
echo "jellyfin=0" >> $install_path/version && \
echo "ffmpeg=0" >> $install_path/version

UpgradeJellyfinGenericLinux () {
    # Get latest version number from download website
    jellyfin_newversion=$(wget --quiet -O - https://repo.jellyfin.org/files/server/linux/latest-stable/amd64 | grep -m 1 "amd64.tar.gz" | sed 's/.*_\(.*\)_.*/\1/;s/-amd64.*//')

    # Check if version variables are empty
    if [ -z "$jellyfin_newversion" ]; then
        echo "Error: Failed to retrieve Jellyfin version. Exiting."
        exit 1
    fi

    # Get current installed version of Jellyfin
    jellyfin_oldversion=$(grep jellyfin ./version | sed 's/.*=//')

    # Compare installed version to latest. If same exit function.
    [ "$jellyfin_oldversion" == "$jellyfin_newversion" ]  && echo "Jellyfin already at latest version $jellyfin_newversion" && return

    # Download latest jellyfin and sha256sum then comapre
    wget https://repo.jellyfin.org/files/server/linux/latest-stable/amd64/jellyfin_$jellyfin_newversion-amd64.tar.gz && \
    # Download latest jellyfin
    if ! wget https://repo.jellyfin.org/files/server/linux/latest-stable/amd64/jellyfin_$jellyfin_newversion-amd64.tar.gz; then
        echo "Failed to download Jellyfin $jellyfin_newversion. Check your internet connection or repo availability."
        exit 1
    fi
    jellyfin_md5=$(wget --quiet -O - https://repo.jellyfin.org/?path=/server/linux/latest-stable/amd64 | grep -m 1 "<td>" | sed 's/<td>//;s/<\/td>//') && \
    echo $jellyfin_md5 jellyfin_$jellyfin_newversion-amd64.tar.gz | md5sum --check -

    # Stop jellyin service, extract latest version over old. I use bsdtar because normal tar sometimes failed to overwrite for me.
    sudo systemctl stop jellyfin.service && \
    mv $install_path/jellyfin  $install_path/jellyfin_$jellyfin_oldversion && \

    mkdir -p "$install_path"/jellyfin    
        # Extract using bsdtar and check for errors
    if ! bsdtar --strip-components=1 -xf jellyfin_"$jellyfin_newversion"-amd64.tar.gz -C "$install_path"/jellyfin; then
        # Diagnostic commands run only if bsdtar fails
        echo "Error: bsdtar failed to extract files."
        echo "Running diagnostics..."
        echo "Current user: $(whoami)"
        echo "Directory contents of $install_path:"
        ls -l "$install_path"
        echo "Attempting to extract to $install_path/jellyfin"
        echo "Directory contents of $install_path/jellyfin:"
        ls -l "$install_path/jellyfin"
        # Exit or handle the error appropriately
        exit 1
    fi
    
    rm -rf "$install_path/jellyfin_$jellyfin_oldversion" && \

    # Recreate symlink used in start script
    ln -sf "$install_path/jellyfin_$jellyfin_newversion" "$install_path/jellyfin" && \

    # Clean up downloaded files
    rm jellyfin_"$jellyfin_newversion"-amd64.tar.gz* && \

    # Restart Jellyfin service
    systemctl restart jellyfin.service && \
    # Edit version file
    sed -i "s/jellyfin=$jellyfin_oldversion/jellyfin=$jellyfin_newversion/g" ./version
}

UpgradeJellyfinFfmpegPortable (){
    # Get latest version number of jellyfin-ffmpeg from download site
    ffmpeg_newversion=$(wget --quiet -O - https://repo.jellyfin.org/files/ffmpeg/linux/latest-6.x/amd64 | grep portable | sed 's/^.*ffmpeg_//;s/_portable.*//')

    # Check if version variables are empty
    if [ -z "$ffmpeg_newversion" ]; then
        echo "Error: Failed to retrieve ffmpeg version. Exiting."
        exit 1
    fi

    # Get current installed version of ffmpeg
    ffmpeg_oldversion=$(grep ffmpeg ./version | sed 's/.*=//')

    # Compare installed version to latest. If same exit function.
    [ "$ffmpeg_oldversion" == "$ffmpeg_newversion" ] && echo "Jellyfin-ffmpeg already at latest version $ffmpeg_newversion" && return

    mkdir -p $install_path/jellyfin-ffmpeg && \

    # Download ffmpeg and sha256sum, then compare
	wget https://repo.jellyfin.org/files/ffmpeg/linux/latest-6.x/amd64/jellyfin-ffmpeg_"$ffmpeg_newversion"_portable_linux64-gpl.tar.xz && \
    # Download ffmpeg
    if ! wget https://repo.jellyfin.org/files/ffmpeg/linux/latest-6.x/amd64/jellyfin-ffmpeg_"$ffmpeg_newversion"_portable_linux64-gpl.tar.xz; then
        echo "Failed to download ffmpeg $ffmpeg_newversion. Check your internet connection or repo availability."
        exit 1
    fi
    ffmpeg_md5=$(wget --quiet -O - https://repo.jellyfin.org/?path=/ffmpeg/linux/latest-6.x/amd64 | grep -m 1 "<td>" | sed 's/<td>//;s/<\/td>//') && \
    echo $ffmpeg_md5 jellyfin-ffmpeg_"$ffmpeg_newversion"_portable_linux64-gpl.tar.xz | md5sum --check - && \

    # Extract binaries
    xz --decompress jellyfin-ffmpeg_"$ffmpeg_newversion"_portable_linux64-gpl.tar.xz && \
    #rm jellyfin-ffmpeg_"$ffmpeg_newversion"_portable_linux64-gpl.tar.xz && \
    # Extract ffmpeg binaries and check for errors
    if ! bsdtar --strip-components=1 -xf jellyfin-ffmpeg_"$ffmpeg_newversion"_portable_linux64-gpl.tar -C $install_path/jellyfin-ffmpeg; then
        # Diagnostic commands run only if bsdtar fails
        echo "Error: bsdtar failed to extract ffmpeg files."
        echo "Running diagnostics..."
        echo "Current user: $(whoami)"
        echo "Directory contents of $install_path/jellyfin-ffmpeg:"
        ls -l "$install_path/jellyfin-ffmpeg"
        # Exit or handle the error appropriately
        exit 1
    fi

    # Cleanup downloaded files
    rm jellyfin-ffmpeg_"$ffmpeg_newversion"_portable_linux64-gpl.tar* && \

    # Edit version file
    sed -i "s/ffmpeg=$ffmpeg_oldversion/ffmpeg=$ffmpeg_newversion/g" ./version
}

# Ensure bsdtar is installed
type bsdtar >/dev/null 2>&1 || { echo >&2 "bsdtar is not installed. Aborting."; exit 1; }

UpgradeJellyfinGenericLinux
UpgradeJellyfinFfmpegPortable
