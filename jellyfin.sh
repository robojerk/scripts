cd /opt/jellyfin
latest=$(wget --quiet -O - https://repo.jellyfin.org/releases/server/linux/stable/ | grep -m 1 "combined.*amd64.tar.gz" | sed '
s/.*_\(.*\)_.*/\1/')
[[ -f version ]] || touch version
file="./version" && version=$(cat "$file")
if [ "$version" == "$latest" ]; then
 echo "You're using the latest version at $latest."
else
 wget https://repo.jellyfin.org/releases/server/linux/stable/combined/jellyfin_"$latest"_amd64.tar.gz && \
 wget https://repo.jellyfin.org/releases/server/linux/stable/combined/jellyfin_"$latest"_amd64.tar.gz.sha256sum && \
 sha256sum -c --quiet jellyfin_"$latest"_amd64.tar.gz.sha256sum && \
 sudo systemctl stop jellyfin.service && \
 sudo tar xvzf jellyfin_"$latest"_amd64.tar.gz && \
 rm ./jellyfin
 sudo ln -s jellyfin_"$latest" jellyfin
 sudo systemctl start jellyfin.service && \
 rm jellyfin_"$latest"_amd64.tar.gz* && \
 echo "$latest" > version && \
 echo "Upgraded from $version to $latest."
fi
