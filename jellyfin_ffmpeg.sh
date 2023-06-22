# get latest version of jellyfin-ffmpeg6
tag=$(wget --quiet -O - https://repo.jellyfin.org/releases/server/debian/versions/jellyfin-ffmpeg | sed -e 's/<a href="//' -e 's/\/.*//g' -e '/^[^0-9]/d' | tail -1)
# download .deb file
wget https://repo.jellyfin.org/releases/ffmpeg/"$tag"/jellyfin-ffmpeg_"$tag"_portable_linux64-gpl.tar.xz && \
wget https://repo.jellyfin.org/releases/ffmpeg/"$tag"/jellyfin-ffmpeg_"$tag"_portable_linux64-gpl.tar.xz.sha256sum && \
bsdtar --strip-components=1 -xvf jellyfin-ffmpeg_"$tag"_portable_linux64-gpl.tar.xz && \
mkdir -p jellyfin-ffmpeg6 && \
sha256sum -c --quiet jellyfin_"$latest"_amd64.tar.gz.sha256sum && \
rm jellyfin-ffmpeg_"$tag"_portable_linux64-gpl.tar.xz*
