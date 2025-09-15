#!/bin/bash

# A script to automate the setup of a Debian VM for OSINT.
# This script consolidates and refactors the user's original scripts for better readability,
# error handling, and efficiency.

# Exit immediately if a command exits with a non-zero status.
set -e

# Define a function to log messages with different levels.
log() {
    local level="$1"
    local message="$2"
    case "$level" in
        INFO) echo "[\e[1;34mINFO\e[0m] $message" ;;
        SUCCESS) echo "[\e[1;32mSUCCESS\e[0m] $message" ;;
        WARN) echo "[\e[1;33mWARN\e[0m] $message" ;;
        ERROR) echo "[\e[1;31mERROR\e[0m] $message" >&2; exit 1 ;;
    esac
}

# --- Section 1: System-wide Configuration and Dependencies ---

# Update and upgrade the system
update_system() {
    log INFO "Updating system and installing base packages..."
    sudo apt update
    sudo apt upgrade -y
    sudo apt install -y build-essential curl git wget
    log SUCCESS "System updated."
}

# Configure DNS to use public DNS servers
configure_dns() {
    log INFO "Configuring DNS resolvers..."
    sudo apt install -y resolvconf
    sudo systemctl enable --now resolvconf.service
    
    # Use a single file write with a heredoc for clarity and to prevent multiple appends.
    sudo tee /etc/resolvconf/resolv.conf.d/head > /dev/null <<EOL
nameserver 8.8.8.8
nameserver 8.8.4.4
nameserver 1.1.1.1
nameserver 1.0.0.1
EOL

    sudo resolvconf -u # Update the resolvconf configuration
    log SUCCESS "DNS resolvers configured."
}

# Install core packages from Debian repositories
install_debian_packages() {
    log INFO "Installing Debian packages..."
    # A single apt install command is more efficient.
    sudo apt install -y \
        ruby-dev tcpdump postgresql php emacs redis-tools \
        python3-venv pipx python3-pip httrack webhttrack filezilla \
        mycli pidgin audacity gimp inkscape ffuf wireshark \
        mediainfo-gui libimage-exiftool-perl mat2 tor vlc marble \
        qgis ffmpeg idle ripgrep jq crunch ssh cherrytree \
        keepassxc remmina stegosuite exifprobe ruby-bundler mpg123 \
        thunderbird curl sqlite3 python3-lxml libre-dev \
        snapd proxychains4 flowblade asciinema ufw \
        sqlitebrowser neovim libxcb-cursor0 nmap \
        libcurl4-openssl-dev libxml2 libxml2-dev \
        libxslt1-dev libgmp-dev zlib1g-dev \
        npm freerdp2-x11 ftp smbclient

    log SUCCESS "Debian packages installed."
}

# Start and enable core services
configure_services() {
    log INFO "Starting and enabling services..."
    sudo systemctl enable --now ssh
    sudo systemctl enable --now postgresql
    log SUCCESS "Services configured."
}

# Install Ruby Gems and Snap packages
install_ruby_gems_and_snaps() {
    log INFO "Installing Ruby Gems and Snap packages..."
    # Check if 'gem' and 'snap' commands are available before running.
    if ! command -v gem &> /dev/null; then
        log WARN "Ruby gem command not found. Skipping gem installs."
    else
        gem install mechanize colorize wpscan evil-winrm
    fi

    if ! command -v snap &> /dev/null; then
        log WARN "Snap command not found. Skipping snap installs."
    else
        sudo snap install dbeaver-ce powershell --classic joplin-desktop youtube-dl-pro ngrok localxpose telegram-desktop
    fi
    log SUCCESS "Ruby Gems and Snap packages installed."
}

# Install MongoDB
install_mongodb() {
    log INFO "Installing and configuring MongoDB..."
    # Import the public key used by the package management system
    sudo apt-get install -y gnupg curl
    curl -fsSL https://www.mongodb.org/static/pgp/server-6.0.asc | \
       sudo gpg --dearmor -o /usr/share/keyrings/mongodb-archive-keyring.gpg

    # Create a list file for MongoDB
    echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-archive-keyring.gpg ] https://repo.mongodb.org/apt/debian bullseye/mongodb-org/6.0 main" | sudo tee /etc/apt/sources.list.d/mongodb.list

    # Reload local package database
    sudo apt-get update
    
    # Install MongoDB packages
    sudo apt-get install -y mongodb-org
    
    # Start and enable the service
    sudo systemctl start mongod
    sudo systemctl enable mongod
    
    log SUCCESS "MongoDB installed and configured."
}

# Install the latest version of Go
install_latest_go() {
    log INFO "Installing the latest version of Go..."
    # Get the latest Go version from the official site
    LATEST_GO_VERSION=$(curl -s "https://go.dev/VERSION?m=text")
    GO_URL="https://go.dev/dl/$LATEST_GO_VERSION.linux-amd64.tar.gz"
    
    # Remove any previous Go installation
    sudo rm -rf /usr/local/go
    
    # Download and extract the latest Go tarball
    wget -q --show-progress "$GO_URL" -O /tmp/go.tar.gz
    sudo tar -C /usr/local -xzf /tmp/go.tar.gz
    rm /tmp/go.tar.gz
    
    # Set up Go environment variables for the current user and session
    export GOROOT=/usr/local/go
    export GOPATH="$HOME/go"
    export PATH="$PATH:$GOROOT/bin:$GOPATH/bin"
    
    # Add Go to the user's .bashrc for persistent access
    log INFO "Adding Go to the PATH in ~/.bashrc"
    echo "" >> "$HOME/.bashrc"
    echo "# GoLang Path" >> "$HOME/.bashrc"
    echo "export GOROOT=/usr/local/go" >> "$HOME/.bashrc"
    echo "export GOPATH=\$HOME/go" >> "$HOME/.bashrc"
    echo "export PATH=\$PATH:\$GOROOT/bin:\$GOPATH/bin" >> "$HOME/.bashrc"
    
    log SUCCESS "Go installed and path updated."
}


# --- Section 2: User-specific Tool Installation ---
install_pipx_tools() {
    log INFO "Installing Pipx tools..."
    pipx ensurepath
    # Pipx can install multiple packages at once.
    pipx install \
        ghunt socialscan holehe xeuledoc waybackpy \
        changedetection.io archivebox internetarchive search-that-hash \
        name-that-hash h8mail domain-stats gitem ignorant \
        masto social-analyzer recoverpy whisper-ctranslate2 checkdmarc \
        netlas postleaks postleaksNg androguard bbot toutatis poetry
    
    log SUCCESS "Pipx tools installed."
}

install_go_tools() {
    log INFO "Installing Go tools..."
    export GOPATH="$HOME/go"
    export PATH="$PATH:$GOPATH/bin"
    # Consolidate go install commands.
    go install github.com/tomnomnom/waybackurls@latest
    go install -v github.com/owasp-amass/amass/v4/...@master
    go install github.com/jaeles-project/gospider@latest
    go install github.com/hakluke/hakrawler@latest
    go install github.com/tomnomnom/httprobe@master
    go install -v github.com/owasp-amass/oam-tools/cmd/...@master
    go install github.com/projectdiscovery/katana/cmd/katana@latest
    go install github.com/xxxserxxx/gotop/v4/cmd/gotop@latest
    go install github.com/ndelphit/apkurlgrep@latest
    go install github.com/davecheney/httpstat@latest
    go install github.com/trap-bytes/hauditor@latest
    go install github.com/g0ldencybersec/gungnir/cmd/gungnir@latest
    go install github.com/tantosec/oneshell@latest
    
    # Handle gowitness separately due to its specific installation method.
    wget -q --show-progress https://github.com/sensepost/gowitness/releases/download/2.5.1/gowitness-2.5.1-linux-amd64
    mv gowitness-2.5.1-linux-amd64 "$GOPATH/bin/gowitness"
    chmod +x "$GOPATH/bin/gowitness"
    
    log SUCCESS "Go tools installed."
}

# A function to handle the installation of a single Git repository.
install_git_repo() {
    local repo_url="$1"
    local repo_dir=$(basename "$repo_url" .git)
    local venv_name="$2"
    
    if [ -d "$repo_dir" ]; then
        log WARN "Directory $repo_dir already exists. Skipping git clone."
        return
    fi
    
    log INFO "Cloning and installing $repo_dir..."
    git clone "$repo_url"
    cd "$repo_dir"
    
    if [ -f "requirements.txt" ]; then
        python3 -m venv "$venv_name"
        source "$venv_name/bin/activate"
        pip install -r requirements.txt
        deactivate
    elif [ -f "Pipfile" ]; then
        # Handle poetry projects
        poetry install
    fi
    cd - > /dev/null # Go back to the previous directory silently
    log SUCCESS "$repo_dir installed."
}

# Install Python and other Git-based tools
install_git_and_python_tools() {
    log INFO "Cloning Git repositories and installing Python tools..."
    mkdir -p "$HOME/programs"
    cd "$HOME/programs"
    
    # Use the function to install each tool.
    install_git_repo "https://github.com/AmIJesse/Elasticsearch-Crawler.git" "es-crawler-env"
    install_git_repo "https://github.com/p1ngul1n0/blackbird.git" "blackbird-env"
    install_git_repo "https://github.com/Lazza/Carbon14.git" "carbon14-env"
    install_git_repo "https://github.com/soxoj/maigret.git" "maigret-env"
    (
        cd maigret
        python3 -m venv maigret-env
        source maigret-env/bin/activate
        pip install .
        deactivate
    )
    install_git_repo "https://github.com/D4Vinci/Cr3dOv3r.git" "credover-env"
    install_git_repo "https://github.com/0xZDH/BridgeKeeper.git" "bridgekeeper-env"
    install_git_repo "https://github.com/Healdb/Elevate.git" "elevate-env"
    install_git_repo "https://github.com/thewhiteh4t/pwnedOrNot.git" "pwnedornot-env"
    install_git_repo "https://github.com/AbirHasan2005/LittleBrother.git" "littlebrother-env"
    install_git_repo "https://github.com/C3n7ral051nt4g3ncy/WhatsMyName-Python.git" "wmn-python-env"
    install_git_repo "https://github.com/GuidoBartoli/sherloq.git" "sherloq-env"
    (
        cd sherloq/gui
        python3 -m venv sherloq-env
        source sherloq-env/bin/activate
        pip install -r requirements.txt
        deactivate
        cd - > /dev/null
    )
    install_git_repo "https://github.com/OSINT-TECHNOLOGIES/dpulse.git" "dpulse-env"
    (
        cd dpulse
        poetry install
        cd - > /dev/null
    )
    install_git_repo "https://github.com/chm0dx/creepyCrawler.git" "creepycrawler-env"
    install_git_repo "https://github.com/N0rz3/Eyes.git" "eyes-env"
    install_git_repo "https://github.com/laramies/theHarvester.git" "theharvester-env"
    install_git_repo "https://github.com/opsdisk/metagoofil.git" "metagoofil-env"
    install_git_repo "https://github.com/smicallef/spiderfoot.git" "spiderfoot-env"
    install_git_repo "https://github.com/aboul3la/Sublist3r.git" "sublist3r-env"
    install_git_repo "https://github.com/s0md3v/Photon.git" "photon-env"
    install_git_repo "https://github.com/thewhiteh4t/FinalRecon.git" "finalrecon-env"
    install_git_repo "https://github.com/drego85/tosint.git" "tosint-env"
    install_git_repo "https://github.com/t3l3machus/Villain.git" "villain-env"

    # Handle phoneinfoga separately as it's a binary download.
    log INFO "Downloading and installing phoneinfoga..."
    mkdir -p phoneinfoga
    (
        cd phoneinfoga
        wget -q --show-progress https://github.com/sundowndev/phoneinfoga/releases/download/v2.10.8/phoneinfoga_Linux_x86_64.tar.gz
        tar -xzvf phoneinfoga_Linux_x86_64.tar.gz
        rm phoneinfoga_Linux_x86_64.tar.gz
    )
    log SUCCESS "phoneinfoga installed."

    # Handle gophish separately as it's a zip download.
    log INFO "Downloading and installing gophish..."
    mkdir -p gophish
    (
        cd gophish
        wget -q --show-progress https://github.com/gophish/gophish/releases/download/v0.12.1/gophish-v0.12.1-linux-64bit.zip
        unzip gophish-v0.12.1-linux-64bit.zip
        rm gophish-v0.12.1-linux-64bit.zip
    )
    log SUCCESS "gophish installed."

    # Handle gron separately as it's a tgz download.
    log INFO "Downloading and installing gron..."
    wget -q --show-progress https://github.com/tomnomnom/gron/releases/download/v0.7.1/gron-linux-amd64-0.7.1.tgz
    tar xzf gron-linux-amd64-0.7.1.tgz
    rm gron-linux-amd64-0.7.1.tgz
    log SUCCESS "gron installed."

    # Handle yt-dlp separately as it has dependencies.
    log INFO "Downloading and installing yt-dlp..."
    mkdir -p yt-dlp
    (
        cd yt-dlp
        wget -q --show-progress https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp
        wget -q --show-progress https://github.com/yt-dlp/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-linux64-gpl.tar.xz
        tar -xf ffmpeg-master-latest-linux64-gpl.tar.xz
        rm ffmpeg-master-latest-linux64-gpl.tar.xz
        chmod +x yt-dlp ffmpeg*/bin/*
    )
    log SUCCESS "yt-dlp installed."

    # Download deb packages.
    log INFO "Downloading .deb packages..."
    wget -q --show-progress https://github.com/TermuxHackz/anonphisher/releases/download/3.3.2/anonphisher_3.3.2_all.deb
    wget -q --show-progress https://downloads.mongodb.com/compass/mongodb-mongosh_2.3.1_amd64.deb
    log SUCCESS ".deb packages downloaded."

    # Clone all resource repos into a single directory
    log INFO "Cloning OSINT resource repositories..."
    mkdir -p "$HOME/resources"
    cd "$HOME/resources"
    
    git clone https://github.com/swisskyrepo/InternalAllTheThings.git
    git clone https://github.com/andrewjkerr/security-cheatsheets.git
    git clone https://github.com/cipher387/Dorks-collections-list.git
    git clone https://github.com/cipher387/osint_stuff_tool_collection.git
    git clone https://github.com/ExploitXpErtz/WebCam-Google-Shodan-Dorks.git
    git clone https://github.com/cipher387/cheatsheets.git
    git clone https://github.com/vaib25vicky/awesome-mobile-security.git
    
    mkdir -p tor-links
    (
        cd tor-links
        git clone https://github.com/01Kevin01/OnionLinksV3.git
        git clone https://github.com/fastfire/deepdarkCTI.git
    )
    
    # Amass fresh resolvers
    mkdir -p "$HOME/.config/amass"
    (
        cd "$HOME/.config/amass"
        git clone https://github.com/proabiral/Fresh-Resolvers.git
    )
    log SUCCESS "Git repositories cloned."

    # Ronin install
    log INFO "Installing Ronin..."
    wget -q --show-progress https://raw.githubusercontent.com/ronin-rb/scripts/main/ronin-install.sh
    chmod +x ronin-install.sh
    bash ronin-install.sh
    log SUCCESS "Ronin installed."

    cd - > /dev/null
}

# --- Main script execution flow ---
main() {
    log INFO "Starting OSINT VM setup script."
    update_system
    configure_dns
    install_debian_packages
    configure_services
    install_mongodb
    install_latest_go
    install_ruby_gems_and_snaps
    install_pipx_tools
    install_go_tools
    install_git_and_python_tools
    log SUCCESS "Setup complete! The system is ready for use."
}

# Run the main function.
main
