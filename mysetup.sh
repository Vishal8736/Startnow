#!/bin/bash

# --- Colors for Output ---
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# --- 1. Root Check (Secure Method) ---
# Hum check kar rahe hain ki script SUDO ke sath chalayi gayi hai ya nahi
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[!] Error: Please run this script as root.${NC}"
    echo -e "${YELLOW}Usage: sudo ./setup.sh${NC}"
    exit 1
fi

# --- 2. Real User Detection ---
# Sudo use karne par user 'root' ban jata hai, humein asli user chahiye
REAL_USER=${SUDO_USER:-$USER}

if [ "$REAL_USER" == "root" ]; then
    echo -e "${RED}[!] Error: Do not run this script logged in strictly as root user.${NC}"
    echo -e "${YELLOW}[*] Please login as a normal user and use 'sudo'.${NC}"
    exit 1
fi

REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
echo -e "${BLUE}[+] Setup running for User: $REAL_USER | Home: $REAL_HOME${NC}"

# --- 3. System Update & Dependencies ---
echo -e "${BLUE}[+] Updating System & Installing Base Dependencies...${NC}"
apt update && apt upgrade -y

# Note: Removed 'httpx-toolkit' to avoid conflict with ProjectDiscovery httpx
apt install -y python3-venv python3-full python3-pip golang git curl wget \
libpcap-dev jq seclists dirsearch gobuster nmap build-essential unzip

# --- 4. Python Venv Setup ---
VENV_PATH="$REAL_HOME/tools/venv/pentest_env"
mkdir -p "$(dirname "$VENV_PATH")"

if [ ! -d "$VENV_PATH" ]; then
    echo -e "${BLUE}[+] Creating Python Virtual Environment...${NC}"
    # Run creation as the REAL USER to avoid permission issues later
    sudo -u "$REAL_USER" python3 -m venv "$VENV_PATH"
else
    echo -e "${GREEN}[+] Venv already exists.${NC}"
fi

# Shortcut variables for binaries inside venv
PIP_BIN="$VENV_PATH/bin/pip"

# --- 5. Environment Variables Setup (.bashrc) ---
BASHRC="$REAL_HOME/.bashrc"

# Check if we already added configuration
if ! grep -q "AUTOMATED PENTEST SETUP" "$BASHRC"; then
    echo -e "${BLUE}[+] Configuring .bashrc...${NC}"
    echo "" >> "$BASHRC"
    echo "# --- AUTOMATED PENTEST SETUP ---" >> "$BASHRC"
    echo "export GOPATH=$REAL_HOME/go" >> "$BASHRC"
    echo 'export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin' >> "$BASHRC"
    echo "source $VENV_PATH/bin/activate" >> "$BASHRC"
    
    # Refresh permissions for bashrc
    chown "$REAL_USER:$REAL_USER" "$BASHRC"
fi

# Export for current session so script can continue installing
export GOPATH="$REAL_HOME/go"
export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin

# --- 6. Tool Installation (Go & Python) ---

# Function to install Go tools
install_go_tool() {
    PACKAGE=$1
    TOOL_NAME=$(basename "$PACKAGE" | cut -d@ -f1)
    echo -e "${BLUE}[->] Installing/Updating Go Tool: $TOOL_NAME${NC}"
    
    # Install using Go
    GOPATH="$REAL_HOME/go" go install -v "$PACKAGE"
}

echo -e "${GREEN}[+] Installing ProjectDiscovery & Go Tools...${NC}"
install_go_tool "github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest"
install_go_tool "github.com/projectdiscovery/dnsx/cmd/dnsx@latest"
install_go_tool "github.com/projectdiscovery/katana/cmd/katana@latest"
install_go_tool "github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"
install_go_tool "github.com/projectdiscovery/cvemap/cmd/cvemap@latest"
install_go_tool "github.com/projectdiscovery/httpx/cmd/httpx@latest"
install_go_tool "github.com/projectdiscovery/naabu/v2/cmd/naabu@latest"

install_go_tool "github.com/tomnomnom/assetfinder@latest"
install_go_tool "github.com/tomnomnom/waybackurls@latest"
install_go_tool "github.com/tomnomnom/gf@latest"
install_go_tool "github.com/tomnomnom/httprobe@latest"
install_go_tool "github.com/tomnomnom/fff@latest"

install_go_tool "github.com/ffuf/ffuf/v2@latest"
install_go_tool "github.com/lc/gau/v2/cmd/gau@latest"

echo -e "${GREEN}[+] Installing Python Tools...${NC}"
# Use the pip inside the virtual environment
"$PIP_BIN" install --upgrade pip
"$PIP_BIN" install arjun requests

# --- 7. Git Repositories ---
git_clone_or_pull() {
    REPO_URL=$1
    DEST_DIR=$2
    if [ -d "$DEST_DIR" ]; then
        echo -e "${YELLOW}[*] Updating existing repo: $(basename "$DEST_DIR")...${NC}"
        cd "$DEST_DIR" && git pull
    else
        echo -e "${BLUE}[+] Cloning repo: $(basename "$DEST_DIR")...${NC}"
        git clone "$REPO_URL" "$DEST_DIR"
    fi
}

# GF Patterns Setup
mkdir -p "$REAL_HOME/.gf"
echo -e "${BLUE}[+] Setting up GF Patterns...${NC}"
if [ ! -d "/tmp/gf-patterns" ]; then
    git clone https://github.com/1ndianl33t/Gf-Patterns /tmp/gf-patterns
fi
cp /tmp/gf-patterns/*.json "$REAL_HOME/.gf/"
rm -rf /tmp/gf-patterns

# Custom Tools
mkdir -p "$REAL_HOME/tools/vishal8736"
git_clone_or_pull "https://github.com/vishal8736/v-web.git" "$REAL_HOME/tools/vishal8736/v-web"
git_clone_or_pull "https://github.com/vishal8736/v-reconn.git" "$REAL_HOME/tools/vishal8736/v-reconn"

# --- 8. Custom Manager Function (tools --list) ---
if ! grep -q "tools()" "$BASHRC"; then
cat << EOF >> "$BASHRC"

tools() {
    if [ "\$1" == "--list" ]; then
        echo -e "\e[1;33m--- Pentesting Toolset (Autonomous Mode) ---\e[0m"
        echo "Venv Path: ~/tools/venv/pentest_env"
        echo "Tools: nuclei, subfinder, httpx, katana, dnsx, naabu, assetfinder,"
        echo "       waybackurls, gau, ffuf, arjun, dirsearch, gf, v-web, v-reconn"
        echo -e "\e[1;32mAll tools are activated globally.\e[0m"
    else
        echo "Usage: tools --list"
    fi
}
EOF
fi

# --- 9. Fixing Permissions (Final Step) ---
echo -e "${BLUE}[+] Fixing Ownership and Permissions...${NC}"

# Update Nuclei Templates (as the real user)
if [ -f "$REAL_HOME/go/bin/nuclei" ]; then
    echo -e "${YELLOW}[*] Updating Nuclei Templates...${NC}"
    sudo -u "$REAL_USER" "$REAL_HOME/go/bin/nuclei" -ut >/dev/null 2>&1
fi

# Recursive chown to ensure user owns everything in tools and go
chown -R "$REAL_USER:$REAL_USER" "$REAL_HOME/tools"
chown -R "$REAL_USER:$REAL_USER" "$REAL_HOME/.gf"
chown -R "$REAL_USER:$REAL_USER" "$REAL_HOME/go"
chown "$REAL_USER:$REAL_USER" "$REAL_HOME/.bashrc"

echo -e "${GREEN}======================================================${NC}"
echo -e "${GREEN}      SETUP COMPLETE SUCCESSFULLY!                    ${NC}"
echo -e "${BLUE}    1. Close this terminal and open a new one.${NC}"
echo -e "${BLUE}       (OR run: source ~/.bashrc)${NC}"
echo -e "${BLUE}    2. Type 'tools --list' to verify installation.  ${NC}"
echo -e "${GREEN}======================================================${NC}"
