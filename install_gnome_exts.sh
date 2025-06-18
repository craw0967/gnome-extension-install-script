#!/bin/bash

# Parse extension URLs into array
EXTENSION_URLS_STRING=$1
CLEANED_STRING=$(echo "$EXTENSION_URLS_STRING" | tr -d "[]',")
read -r -a EXTENSION_URLS <<< "$CLEANED_STRING"

# Get Gnome shell version
GN_CMD_OUTPUT=$(gnome-shell --version)
GN_SHELL=${GN_CMD_OUTPUT:12:2}

CHANGED="false"

for i in "${EXTENSION_URLS[@]}"
do
    # Get extension ID from extension page
    EXTENSION_ID=$(curl -s $i | grep -oP 'data-uuid="\K[^"]+')

    # Get extension version that works with current shell
    VERSION_LIST_TAG=$(curl -Lfs "https://extensions.gnome.org/extension-query/?uuid=${EXTENSION_ID}" | jq '.extensions[] | select(.uuid=="'"${EXTENSION_ID}"'")') 
    VERSION_TAG="$(echo "$VERSION_LIST_TAG" | jq '.shell_version_map |."'"${GN_SHELL}"'" | ."pk"')"
    VERSION="$(echo "$VERSION_LIST_TAG" | jq '.shell_version_map |."'"${GN_SHELL}"'" | ."version"')"

    echo "The version tage list: ${VERSION_LIST_TAG}"
    # Check if extension is already installed
    INSTALLED_EXTENSIONS=$(gnome-extensions list --enabled)
    if echo "$INSTALLED_EXTENSIONS" | grep -q "$EXTENSION_ID"; then
        # Get installed extension version
        INSTALLED_VERSION=$(gnome-extensions info "$EXTENSION_ID" | grep "Version:" | cut -d ":" -f2- | tr -d " ")
        if [ "$INSTALLED_VERSION" == "$VERSION" ]; then
            echo "Extension $EXTENSION_ID is already installed with version $VERSION, skipping..."
            continue
        else
            echo "Extension $EXTENSION_ID is installed with version $INSTALLED_VERSION, but version $VERSION is available, updating..."
        fi
    else
        echo "Extension $EXTENSION_ID is not installed, installing..."
    fi

    # Download extension
    wget -O "${EXTENSION_ID}".zip "https://extensions.gnome.org/download-extension/${EXTENSION_ID}.shell-extension.zip?version_tag=$VERSION_TAG"
    
    # Install and enable extension
    dbus-launch gnome-extensions install --force "${EXTENSION_ID}".zip
    dbus-launch gnome-extensions enable ${EXTENSION_ID}
    
    # Clean up
    rm ${EXTENSION_ID}.zip
done
