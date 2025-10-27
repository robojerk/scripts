#!/bin/bash
# Tesseract Static Installer for Immutable Distros
# Installs tesseract-static binary and language data to user space
# Based on: https://github.com/DanielMYT/tesseract-static
set -euo pipefail
IFS=$'\n\t'

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="$HOME/.local/opt/tesseract"
BIN_DIR="$HOME/.local/bin"
TESSDATA_DIR="$HOME/.local/share/tessdata"
TESSERACT_VERSION="tesseract-5.5.1" # Fallback version
GH_USER="DanielMYT"
GH_REPO="tesseract-static"
TEMP_FILE="$(mktemp /tmp/tesseract.XXXXXX)"

# Cleanup function
cleanup() {
    rm -f "$TEMP_FILE"
}
trap cleanup EXIT

# Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)
        BINARY_NAME="tesseract.x86_64"
        ;;
    aarch64)
        BINARY_NAME="tesseract.aarch64"
        ;;
    *)
        echo -e "${RED}Error: Unsupported architecture: $ARCH${NC}"
        exit 1
        ;;
esac

echo -e "${GREEN}Installing Tesseract Static (${TESSERACT_VERSION}) for ${ARCH}${NC}"

# Create necessary directories
echo "Creating directories..."
mkdir -p "$INSTALL_DIR" "$BIN_DIR" "$TESSDATA_DIR"

# Download tesseract binary
echo "Downloading tesseract binary..."
DOWNLOAD_URL="https://github.com/${GH_USER}/${GH_REPO}/releases/download/${TESSERACT_VERSION}/${BINARY_NAME}"
if ! curl -fLs "$DOWNLOAD_URL" -o "$TEMP_FILE"; then
    echo -e "${RED}Error: Failed to download tesseract binary${NC}"
    echo "URL: $DOWNLOAD_URL"
    exit 1
fi

# Move binary to install directory
mv "$TEMP_FILE" "$INSTALL_DIR/tesseract"
chmod +x "$INSTALL_DIR/tesseract"

# Function to create wrapper script
create_wrapper() {
    cat > "$BIN_DIR/tesseract" << 'EOF'
#!/bin/bash
export TESSDATA_PREFIX="$HOME/.local/share/tessdata"
exec "$HOME/.local/opt/tesseract/tesseract" "$@"
EOF
    chmod +x "$BIN_DIR/tesseract"
    echo "Wrapper script created at $BIN_DIR/tesseract"
}

# Create wrapper script
if [ -f "$BIN_DIR/tesseract" ]; then
    if [ ! -L "$BIN_DIR/tesseract" ] || [ "$(readlink -f "$BIN_DIR/tesseract" 2>/dev/null)" != "$INSTALL_DIR/tesseract" ]; then
        echo -e "${YELLOW}Warning: Existing tesseract file already exists${NC}"
        read -p "Overwrite? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Skipping wrapper script creation."
        else
            create_wrapper
        fi
    else
        create_wrapper
    fi
else
    create_wrapper
fi

# Check if ~/.local/bin is in PATH
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    echo -e "${YELLOW}Warning: $BIN_DIR is not in your PATH${NC}"
    echo "Add this to your ~/.bashrc or ~/.zshrc:"
    echo "export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

# Download English training data (optional)
echo -e "${YELLOW}Tesseract requires language training data to function.${NC}"
read -p "Download English training data (eng.traineddata)? [Y/n] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    echo "Downloading English training data..."
    LANG_DATA_URL="https://github.com/tesseract-ocr/tessdata_best/raw/main/eng.traineddata"
    if curl -fLs "$LANG_DATA_URL" -o "$TESSDATA_DIR/eng.traineddata"; then
        echo -e "${GREEN}✓ English training data downloaded${NC}"
    else
        echo -e "${RED}Warning: Failed to download training data${NC}"
        echo "You can download it manually from:"
        echo "https://github.com/tesseract-ocr/tessdata_best"
    fi
fi

echo -e "${GREEN}Installation complete!${NC}"
echo ""
echo "Tesseract is ready to use! The wrapper script automatically sets TESSDATA_PREFIX."
echo ""
echo "Example usage:"
echo "tesseract image.png output"
