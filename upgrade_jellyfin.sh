#!/bin/bash

# This script will upgrade the "Generic Linux" version of Jellyfin, and upgrade the portable jellyfin-ffmpeg portable if requested.

# Uncomment the ffmpeg line if you do NOT want to install and update ffmpeg portable.
install_path=/opt/jellyfin
#ffmpeg=skip

mkdir -p $install_path
cd $install_path

# if not exist, create version file. You can delete the version file to force upgrade
if [ ! -f $install_path/version ]
then
        touch $install_path/version && echo "jellyfin=0" >> $install_path/version && echo "ffmpeg=$ffmpeg" >> $install_path/version
fi

UpgradeJellyfinGenericLinux () {
    # Get latest version number from download website
    jellyfin_newversion=$(wget --quiet -O - https://repo.jellyfin.org/releases/server/linux/stable/ | grep -m 1 "combined.*amd64.tar.gz" | sed 's/.*_\(.*\)_.*/\1/')

    # Get current installed version of Jellyfin
    jellyfin_oldversion=$(grep jellyfin ./version | sed 's/.*=//')

    # Compare installed version to latest. If same exit function.
    if [[ "$jellyfin_oldversion" == "$jellyfin_newversion" ]]
    then
        echo "You're using the latest version at $jellyfin_newversion."
        return
    fi

    # Download latest jellyfin and sha256sum then comapre
    wget https://repo.jellyfin.org/releases/server/linux/stable/combined/jellyfin_"$jellyfin_newversion"_amd64.tar.gz && \
    wget https://repo.jellyfin.org/releases/server/linux/stable/combined/jellyfin_"$jellyfin_newversion"_amd64.tar.gz.sha256sum && \
    sha256sum -c --quiet jellyfin_"$jellyfin_newversion"_amd64.tar.gz.sha256sum && \

    # Stop jellyin service, extract latest version over old. I use bsdtar because normal tar sometimes failed to overwrite for me.
    sudo systemctl stop jellyfin.service && \
    bsdtar --strip-components=1 -xf jellyfin_"$jellyfin_newversion"_amd64.tar.gz && \

    # Recreate symlink used in start script
    ln -sf jellyfin_"$jellyfin_newversion" jellyfin && \

    # Clean up downloaded files
    rm jellyfin_"$jellyfin_newversion"_amd64.tar.gz* && \

    # Restart Jellyfin service
    sudo systemctl start jellyfin.service && \

    # Edit version file and notify user upgrade was successful
    sed -i "s/jellyfin=$jellyfin_oldversion/jellyfin=$jellyfin_newversion/g" ./version && \
    echo "Upgraded from $jellyfin_oldversion to $jellyfin_newversion."
}

UpgradeJellyfinFfmpegPortable () {
    if [["$ffmpeg" == "skip"]]; then return; fi

    # Get latest version number of jellyfin-ffmpeg6 from download site
    ffmpeg_newversion=$(wget --quiet -O - https://repo.jellyfin.org/releases/ffmpeg/ | sed -e 's/<a href="//' -e 's/\/.*//g' -e '/^[^0-9]/d' | tail -1)

    # Get current installed version of ffmpeg
    ffmpeg_oldversion=$(grep ffmpeg ./version | sed 's/.*=//')

    # Compare installed version to latest. If same exit function.
    if [[ "$ffmpeg_oldversion" == "$ffmpeg_newversion" ]]
    then
        echo "You're using the latest version at $ffmpeg_oldversion."
        return
    fi

    mkdir -p $install_path/jellyfin-ffmpeg6 && \

    # Download ffmpeg and sha256sum, then compare
    wget https://repo.jellyfin.org/releases/ffmpeg/"$ffmpeg_newversion"/jellyfin-ffmpeg_"$ffmpeg_newversion"_portable_linux64-gpl.tar.xz && \
    wget https://repo.jellyfin.org/releases/ffmpeg/"$ffmpeg_newversion"/jellyfin-ffmpeg_"$ffmpeg_newversion"_portable_linux64-gpl.tar.xz.sha256sum && \
    sha256sum -c --quiet jellyfin-ffmpeg_"$ffmpeg_newversion"_portable_linux64-gpl.tar.xz.sha256sum && \

    # Extract binaries
    bsdtar -xf jellyfin-ffmpeg_"$ffmpeg_newversion"_portable_linux64-gpl.tar.xz -C $install_path/jellyfin-ffmpeg6 && \

    # Cleanup downloaded files
    rm jellyfin-ffmpeg_"$ffmpeg_newversion"_portable_linux64-gpl.tar.xz*

    # Edit version file and notify user upgrade was successful
    sed -i "s/ffmpeg=$ffmpeg_oldversion/ffmpeg=$ffmpeg_newversion/g" ./version && \
    echo "Upgraded from $ffmpeg_oldversion to $ffmpeg_newversion."
}

UpgradeJellyfinGenericLinux
UpgradeJellyfinFfmpegPortable
