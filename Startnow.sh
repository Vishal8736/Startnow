#!/bin/bash

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# 1. Root Check aur Auto-Login logic
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[!] Aap root user nahi hain. Root access lene ki koshish kar rahe hain...${NC}"
    # password 'paro$$' ka use karke sudo command chalana
    echo "paro$$" | sudo -S -v >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[+] Root access granted!${NC}"
        # Script ko khud root ke taur par dubara chalana
        echo "paro$$" | sudo -S "$0" "$@"
        exit $?
    else
        echo -e "${RED}[-][-] Password galat hai ya sudo access nahi mila.${NC}"
        exit 1
    fi
fi

echo -e "${BLUE}[+] User: $(whoami) | Sabhi systems ready hain...${NC}"

# 2. System Update
apt update && apt upgrade -y

# 3. Virtual Environment Setup
echo -e "${BLUE}[+] Python Virtual Environment (venv) banaya ja raha hai...${NC}"
apt install -y python3-venv python3-full
mkdir -p ~/tools/venv
python3 -m venv ~/tools/venv/pentest_env

# Virtual Environment activate karne ka shortcut
source ~/tools/venv/pentest_env/bin/activate

# 4. Core Dependencies
apt install -y golang git curl wget libpcap-dev jq seclists httpx-toolkit dirsearch gobuster nmap

# 5. Go Path Setup
export GOPATH=$HOME/go
export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin
if ! grep -q "GOPATH" ~/.bashrc; then
    echo 'export GOPATH=$HOME/go' >> ~/.bashrc
    echo 'export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin' >> ~/.bashrc
    echo 'source ~/tools/venv/pentest_env/bin/activate' >> ~/.bashrc
fi

# 6. Tools Installation (Go & Python inside Venv)
echo -e "${GREEN}[+] Sabhi tools install ho rahe hain...${NC}"

# ProjectDiscovery
go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
go install -v github.com/projectdiscovery/dnsx/cmd/dnsx@latest
go install -v github.com/projectdiscovery/katana/cmd/katana@latest
go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install -v github.com/projectdiscovery/cvemap/cmd/cvemap@latest
go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest
go install -v github.com/projectdiscovery/naabu/v2/cmd/naabu@latest

# Tomnomnom
go install github.com/tomnomnom/assetfinder@latest
go install github.com/tomnomnom/waybackurls@latest
go install github.com/tomnomnom/gf@latest
go install github.com/tomnomnom/httprobe@latest
go install github.com/tomnomnom/fff@latest

# Extra Power Tools
go install github.com/ffuf/ffuf/v2@latest
go install github.com/lc/gau/v2/cmd/gau@latest
pip install arjun requests

# Patterns & Repos
mkdir -p ~/.gf
git clone https://github.com/1ndianl33t/Gf-Patterns /tmp/gf-patterns
cp /tmp/gf-patterns/*.json ~/.gf/

mkdir -p ~/tools/vishal8736
git clone https://github.com/vishal8736/v-web.git ~/tools/vishal8736/v-web
git clone https://github.com/vishal8736/v-reconn.git ~/tools/vishal8736/v-reconn

# 7. Custom Manager Function
if ! grep -q "tools()" ~/.bashrc; then
cat << 'EOF' >> ~/.bashrc
tools() {
    if [ "$1" == "--list" ]; then
        echo -e "\e[1;33m--- Pentesting Toolset (Autonomous Mode) ---\e[0m"
        echo "Venv Path: ~/tools/venv/pentest_env"
        echo "Tools: nuclei, subfinder, httpx, katana, dnsx, naabu, assetfinder,"
        echo "       waybackurls, gau, ffuf, arjun, dirsearch, gf, v-web, v-reconn"
        echo -e "\e[1;32mSabhie tools globaly activate hain.\e[0m"
    else
        echo "Usage: tools --list"
    fi
}
EOF
fi

# Nuclei update
nuclei -ut

echo -e "${GREEN}==============================================${NC}"
echo -e "${GREEN}      ROOT LOGIN & VENV SETUP COMPLETE!       ${NC}"
echo -e "${BLUE}   Type 'source ~/.bashrc' and 'tools --list' ${NC}"
echo -e "${GREEN}==============================================${NC}"
