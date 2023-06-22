# This is where I install jellyfin
cd /opt/jellyfin
# Get latest version number and put it in file version
latest=$(wget --quiet -O - https://repo.jellyfin.org/releases/server/linux/stable/ | grep -m 1 "combined.*amd64.tar.gz" | sed '
s/.*_\(.*\)_.*/\1/')
[[ -f version ]] || touch version && version=$(cat ./version)
# Compare installed version to latest
if [ "$version" == "$latest" ]; then
 echo "You're using the latest version at $latest."
 exit
else
 # Download latest jellyfin and sha256sum and comapre
 wget https://repo.jellyfin.org/releases/server/linux/stable/combined/jellyfin_"$latest"_amd64.tar.gz && \
 wget https://repo.jellyfin.org/releases/server/linux/stable/combined/jellyfin_"$latest"_amd64.tar.gz.sha256sum && \
 sha256sum -c --quiet jellyfin_"$latest"_amd64.tar.gz.sha256sum && \
 # Stop jellyin and extract latest version over old. I use bsdtar because normal tar sometimes failed to overwrite for me.
 sudo systemctl stop jellyfin.service && \
 bsdtar  --strip-components=1 -xvf jellyfin_"$latest"_amd64.tar.gz && \
 sudo ln -s jellyfin_"$latest" jellyfin
 sudo systemctl start jellyfin.service && \
 rm jellyfin_"$latest"_amd64.tar.gz* && \
 echo "$latest" > version && \
 echo "Upgraded from $version to $latest."
fi
