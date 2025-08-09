#!/bin/bash

# Arch Linux installation script adapted for Hyprland (Wayland-only)

# Ask for sudo password once
sudo -v

# Keep sudo alive during script execution
( while true; do sudo -n true; sleep 60; done ) &
KEEP_SUDO_PID=$!

# Stop the background process at the end of the script
trap 'kill $KEEP_SUDO_PID' EXIT

set -eu

echo "Updating system..."
sudo pacman -Suy --noconfirm

# Install packages
install_packages() {
    echo "Installing essential packages..."

    sudo pacman -S --noconfirm --needed \
        openssh noto-fonts-cjk hplip curl cups cups-pdf cups-pk-helper \
        foomatic-db foomatic-db-engine foomatic-db-gutenprint-ppds \
        foomatic-db-nonfree foomatic-db-nonfree-ppds foomatic-db-ppds \
        gutenprint libcups vlc nmap git python-pip timeshift bluez zip unzip \
        base-devel make flatpak openvpn libreoffice-still chromium \
        avahi nss-mdns nano xorg-xwayland uwsm hyprshot swaylock dolphin \
        gnome-software gnome-text-editor simple-scan xdg-desktop-portal-hyprland
}

# Configure printers
configure_printers() {
    echo "Configuring printing services..."
    sudo systemctl enable --now cups.socket
    sudo systemctl enable --now avahi-daemon

    NSSWITCH_CONF="/etc/nsswitch.conf"
    sudo cp "$NSSWITCH_CONF" "$NSSWITCH_CONF.bak"
    sudo sed -i 's/^hosts:.*/hosts: mymachines mdns_minimal [NOTFOUND=return] resolve [!UNAVAIL=return] files myhostname dns/' "$NSSWITCH_CONF"
}

# Install Flatpak applications
install_flatpak_apps() {
    echo "Installing Flatpak applications..."
    sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

    apps=("org.torproject.torbrowser-launcher" "com.spotify.Client" "com.discordapp.Discord" "net.cozic.joplin_desktop")
    for app in "${apps[@]}"; do
        sudo flatpak install flathub "$app" -y
    done
}

# Set up OpenVPN
setup_openvpn() {
    echo "Setting up OpenVPN..."
    SCRIPT_URL="https://raw.githubusercontent.com/jonathanio/update-systemd-resolved/master/update-systemd-resolved"
    SCRIPT_PATH="/etc/openvpn/update-resolv-conf"
    CLIENT_CONF="/etc/openvpn/client/client.conf"
    POLKIT_RULES="/etc/polkit-1/rules.d/00-openvpn-resolved.rules"

    sudo curl -o $SCRIPT_PATH $SCRIPT_URL
    sudo chmod +x $SCRIPT_PATH

    sudo mkdir -p /etc/openvpn/client
    sudo bash -c "cat >> $CLIENT_CONF << 'EOF'
script-security 2
setenv PATH /usr/bin
up $SCRIPT_PATH
down $SCRIPT_PATH
down-pre
dhcp-option DOMAIN-ROUTE .
EOF"

    sudo bash -c "cat > $POLKIT_RULES << 'EOF'
polkit.addRule(function(action, subject) {
    if (action.id.match(/org.freedesktop.resolve1.set-.*/)) {
        if (subject.user == 'openvpn') {
            return polkit.Result.YES;
        }
    }
});
EOF"

    sudo systemctl enable --now systemd-resolved
}

# Install yay and AUR packages
install_yay_and_aur() {
    echo "Installing yay and AUR packages..."
    sudo pacman -S --needed git base-devel

    if [ ! -d yay ]; then
        git clone https://aur.archlinux.org/yay.git
    fi
    cd yay
    makepkg -si --noconfirm
    cd ..

    packages=("visual-studio-code-bin" "vmware-keymaps" "vmware-workstation" "walker" "ttf-orbitron" "ttf-3270-nerd")
    for package in "${packages[@]}"; do
        yay -S "$package" --noconfirm
    done
}

# Chromium TODO note
chromium_TODO() {
    echo "Adding Chromium TODO note..."
    mkdir -p ~/Documents
    cat <<EOL > ~/Documents/chromium_todo.txt
Install Bitwarden, uBlock Origin, WebRTC Control
EOL
}

# Configure Fastfetch in .bashrc
setup_fastfetch() {
    echo "Configuring Fastfetch..."
    if ! command -v fastfetch &> /dev/null; then
        sudo pacman -S fastfetch --noconfirm
    fi
    grep -q "fastfetch" ~/.bashrc || echo "fastfetch" >> ~/.bashrc
}

# Edit .bashrc with aliases
edit_bashrc() {
    grep -q "alias timeshift='sudo -E timeshift-gtk'" ~/.bashrc || echo "alias timeshift='sudo -E timeshift-gtk'" >> ~/.bashrc
    grep -q "alias orphans='sudo pacman -Qdtq | sudo pacman -Rns -'" ~/.bashrc || echo "alias orphans='sudo pacman -Qdtq | sudo pacman -Rns -'" >> ~/.bashrc
}

# Configure nano
setup_nanorc() {
    echo "Configuring nano..."
    cat <<'EOF' > ~/.nanorc
include /usr/share/nano/*.nanorc
set linenumbers
#set syntax "default"
EOF
}

# Main execution
echo "Starting installation script for Hyprland..."
install_packages
configure_printers
install_flatpak_apps
setup_openvpn
install_yay_and_aur
chromium_TODO
setup_fastfetch
edit_bashrc
setup_nanorc
echo "Installation completed for Hyprland."

