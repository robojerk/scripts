#!/bin/bash
# Discord Installer for Immutable Distros (User-Local)
# Installs Discord into ~/.local/opt/Discord, creates desktop entry, copies PNG icon to user’s icon directory, and optional symlink.
# Designed for immutable systems — no modification of /usr/bin or package manager.
#
# Features:
# - Immutable-safe (installs under ~/.local)
# - Atomic extraction (avoids partial installs)
# - Secure permissions allowing self-updates
# - Auto Wayland detection
# - Optional /usr/local/bin symlink (if writable)
# - Copies discord.png to ~/.local/share/icons and uses Icon=discord in .desktop file
set -euo pipefail
IFS=$'\n\t'

# --- CONFIGURATION ---
INSTALL_DIR="$HOME/.local/opt/Discord"
TEMP_FILE="$(mktemp /tmp/discord.XXXXXX.tar.gz)"
DOWNLOAD_URL="https://discord.com/api/download?platform=linux&format=tar.gz"
DESKTOP_FILE="$HOME/.local/share/applications/discord.desktop"
ICON_DIR="$HOME/.local/share/icons"
ICON_FILE="$ICON_DIR/discord.png"
APP_NAME="Discord"

cleanup() {
    rm -f "$TEMP_FILE"
}
trap cleanup EXIT

echo "📦 Downloading latest Discord tar.gz..."
wget -O "$TEMP_FILE" "$DOWNLOAD_URL" || {
    echo "❌ Failed to download Discord tar.gz."
    exit 1
}

# Verify file exists and is non-empty
if [ ! -s "$TEMP_FILE" ]; then
    echo "❌ Downloaded file is empty or missing."
    exit 1
fi

# Create parent directory
mkdir -p "$(dirname "$INSTALL_DIR")"

# Extract to a temporary staging directory for atomic replacement
STAGING_DIR="$(mktemp -d /tmp/discord_extract.XXXXXX)"
echo "📂 Extracting to staging directory..."
tar -xzf "$TEMP_FILE" -C "$STAGING_DIR" || {
    echo "❌ Failed to extract archive."
    rm -rf "$STAGING_DIR"
    exit 1
}

# Replace existing install atomically
echo "🔁 Installing to $INSTALL_DIR..."
rm -rf "$INSTALL_DIR"
mv "$STAGING_DIR/Discord" "$INSTALL_DIR"
rm -rf "$STAGING_DIR"

# Verify binary exists
if [ ! -x "$INSTALL_DIR/Discord" ]; then
    echo "❌ Discord binary missing after extraction."
    exit 1
fi

# Adjust permissions: writable by user, read/execute by others (safe for self-update)
echo "🔒 Setting permissions..."
chmod -R u+rwX,go+rX "$INSTALL_DIR"

# Copy PNG icon to user’s icon directory
if [ -f "$INSTALL_DIR/discord.png" ]; then
    echo "🖼️ Copying PNG icon to $ICON_FILE..."
    mkdir -p "$ICON_DIR"
    cp "$INSTALL_DIR/discord.png" "$ICON_FILE" || {
        echo "⚠️ Failed to copy PNG icon to $ICON_FILE."
    }
    chmod u+rwX,go+rX "$ICON_FILE" 2>/dev/null || true
    ICON="discord"
else
    echo "⚠️ PNG icon not found at $INSTALL_DIR/discord.png, using generic icon name."
    ICON="discord"
fi

# Create .desktop entry
mkdir -p "$(dirname "$DESKTOP_FILE")"
if [ -f "$INSTALL_DIR/discord.desktop" ]; then
    echo "🖥️ Installing provided desktop entry..."
    cp "$INSTALL_DIR/discord.desktop" "$DESKTOP_FILE"
    # Update Icon field in provided desktop file to use 'discord'
    sed -i "s|^Icon=.*|Icon=$ICON|" "$DESKTOP_FILE"
else
    echo "⚙️ Creating desktop entry..."
    cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Name=Discord
Exec=$INSTALL_DIR/Discord %U
Type=Application
Icon=$ICON
Terminal=false
Categories=Network;InstantMessaging;
Comment=All-in-one voice and text chat
EOF
fi

# Auto-detect Wayland and adjust Exec line
if [ "${XDG_SESSION_TYPE:-}" = "wayland" ]; then
    echo "🌊 Detected Wayland session — enabling Wayland support..."
    sed -i "s|^Exec=.*|Exec=env DISCORD_OZONE_PLATFORM=wayland $INSTALL_DIR/Discord %U|" "$DESKTOP_FILE"
fi

# Try to create a CLI symlink if possible
if [ -w /usr/local/bin ]; then
    echo "🔗 Creating /usr/local/bin/discord symlink..."
    sudo ln -sf "$INSTALL_DIR/Discord" /usr/local/bin/discord 2>/dev/null || \
        echo "⚠️ Could not create symlink (may be immutable)."
else
    echo "⚠️ /usr/local/bin not writable — skipping symlink."
fi

# Update desktop database and icon cache (if available)
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
gtk-update-icon-cache "$HOME/.local/share/icons" 2>/dev/null || true

echo "✅ Discord installed successfully!"
echo "Run it via your app menu or with: $INSTALL_DIR/Discord"
