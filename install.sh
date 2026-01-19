#!/bin/bash

# Set environment
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Parameters
SERVER_KEY="$1"
GATEWAY="${2:-https://hop.uptimematrix.com}"
LOG=/tmp/uptimematrix.log

# ============================================
# PRE-FLIGHT CHECKS - Run before anything else
# ============================================

preflight_errors=()
preflight_warnings=()

# Check 1: Root privileges
if [ "$(id -u)" != "0" ]; then
    preflight_errors+=("Root privileges required|Run with sudo: sudo bash install.sh <server-key>")
fi

# Check 2: Server key provided
if [ -z "$SERVER_KEY" ]; then
    preflight_errors+=("Server key parameter is missing|Usage: bash install.sh <server-key> [gateway-url]")
fi

# Check 3: Gateway URL format
if [[ ! "$GATEWAY" =~ ^https?:// ]]; then
    preflight_errors+=("Invalid Gateway URL format|Must start with http:// or https://")
fi

# Check 4: Network connectivity (basic DNS check)
if command -v host >/dev/null 2>&1; then
    if ! host hop.uptimematrix.com >/dev/null 2>&1; then
        preflight_errors+=("Cannot resolve hop.uptimematrix.com|Check your internet connection and DNS settings")
    fi
elif command -v nslookup >/dev/null 2>&1; then
    if ! nslookup hop.uptimematrix.com >/dev/null 2>&1; then
        preflight_errors+=("Cannot resolve hop.uptimematrix.com|Check your internet connection and DNS settings")
    fi
elif command -v ping >/dev/null 2>&1; then
    if ! ping -c 1 -W 3 hop.uptimematrix.com >/dev/null 2>&1; then
        preflight_warnings+=("Cannot ping hop.uptimematrix.com|Network may be restricted, but installation might still work")
    fi
fi

# Check 5: GitHub connectivity
if command -v host >/dev/null 2>&1; then
    if ! host raw.githubusercontent.com >/dev/null 2>&1; then
        preflight_errors+=("Cannot resolve raw.githubusercontent.com|Check your internet connection or firewall settings")
    fi
elif command -v nslookup >/dev/null 2>&1; then
    if ! nslookup raw.githubusercontent.com >/dev/null 2>&1; then
        preflight_errors+=("Cannot resolve raw.githubusercontent.com|Check your internet connection or firewall settings")
    fi
fi

# Check 6: Package manager available
has_pkg_manager=0
command -v apt-get >/dev/null 2>&1 && has_pkg_manager=1
command -v yum >/dev/null 2>&1 && has_pkg_manager=1
command -v pacman >/dev/null 2>&1 && has_pkg_manager=1
command -v zypper >/dev/null 2>&1 && has_pkg_manager=1
command -v emerge >/dev/null 2>&1 && has_pkg_manager=1
[ -f "/etc/slackware-version" ] && command -v slackpkg >/dev/null 2>&1 && has_pkg_manager=1

if [ $has_pkg_manager -eq 0 ]; then
    preflight_warnings+=("No supported package manager found|Dependencies (cron, curl, wget) must be installed manually")
fi

# Display pre-flight results if there are issues
if [ ${#preflight_errors[@]} -gt 0 ] || [ ${#preflight_warnings[@]} -gt 0 ]; then
    echo ""
    echo -e "\033[0;31m==============================================\033[0m"
    echo -e "\033[0;31m   PRE-FLIGHT CHECK FAILED\033[0m"
    echo -e "\033[0;31m==============================================\033[0m"
    echo ""

    if [ ${#preflight_errors[@]} -gt 0 ]; then
        echo -e "\033[0;31mERRORS (must fix before installation):\033[0m"
        echo ""
        error_num=1
        for err in "${preflight_errors[@]}"; do
            issue="${err%%|*}"
            fix="${err##*|}"
            echo -e "\033[0;31m  $error_num. $issue\033[0m"
            echo -e "\033[1;33m     -> FIX: $fix\033[0m"
            echo ""
            ((error_num++))
        done
    fi

    if [ ${#preflight_warnings[@]} -gt 0 ]; then
        echo -e "\033[1;33mWARNINGS (may cause issues):\033[0m"
        echo ""
        warn_num=1
        for warn in "${preflight_warnings[@]}"; do
            issue="${warn%%|*}"
            fix="${warn##*|}"
            echo -e "\033[1;33m  $warn_num. $issue\033[0m"
            echo -e "\033[0;36m     -> FIX: $fix\033[0m"
            echo ""
            ((warn_num++))
        done
    fi

    if [ ${#preflight_errors[@]} -gt 0 ]; then
        echo -e "\033[0;31m==============================================\033[0m"
        echo -e "\033[1;37mPlease resolve the errors above and try again.\033[0m"
        echo -e "\033[0;31m==============================================\033[0m"
        echo ""
        echo -e "\033[1;33mUsage: bash install.sh <server-key> [gateway-url]\033[0m"
        echo -e "\033[0;36mExample: bash install.sh ABC123DEF456\033[0m"
        echo -e "\033[0;36mExample: bash install.sh ABC123DEF456 https://hop.uptimematrix.com\033[0m"
        echo ""
        exit 1
    fi

    # Only warnings - ask user if they want to continue
    read -n 1 -p "Do you want to continue despite warnings? [Y/n] " reply
    echo ""
    if [[ "$reply" =~ ^[Nn]$ ]]; then
        echo ""
        echo -e "\033[1;33mInstallation cancelled.\033[0m"
        exit 1
    fi
    echo ""
fi

# ============================================
# END PRE-FLIGHT CHECKS
# ============================================

# Clear the screen
clear

# Color support for legacy systems
if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
    # Check if terminal supports colors
    ncolors=$(tput colors 2>/dev/null)
    if [ -n "$ncolors" ] && [ $ncolors -ge 8 ]; then
        RED='\033[0;31m'
        GREEN='\033[0;32m'
        YELLOW='\033[1;33m'
        BLUE='\033[0;34m'
        CYAN='\033[0;36m'
        WHITE='\033[1;37m'
        BOLD='\033[1m'
        NC='\033[0m' # No Color
    else
        RED='' GREEN='' YELLOW='' BLUE='' CYAN='' WHITE='' BOLD='' NC=''
    fi
else
    RED='' GREEN='' YELLOW='' BLUE='' CYAN='' WHITE='' BOLD='' NC=''
fi

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${WHITE}   Welcome to UptimeMatrix Agent Installer${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo " "
echo -e "${WHITE}Configuration:${NC}"
echo -e "${CYAN}   Gateway: $GATEWAY${NC}"
echo " "

### install Dependencies here
echo -e "${CYAN}➜ Installing Dependencies...${NC}"

# RHEL / CentOS / etc
if [ -n "$(command -v yum)" ]; then
	yum -y install cronie gzip curl >> $LOG 2>&1
	service crond start >> $LOG 2>&1
	chkconfig crond on >> $LOG 2>&1

	# Check if perl available or not
	if ! type "perl" >> $LOG 2>&1; then
		yum -y install perl >> $LOG 2>&1
	fi

	# Check if unzip available or not
	if ! type "unzip" >> $LOG 2>&1; then
		yum -y install unzip >> $LOG 2>&1
	fi

	# Check if curl available or not
	if ! type "curl" >> $LOG 2>&1; then
		yum -y install curl >> $LOG 2>&1
	fi
fi

# Debian / Ubuntu
if [ -n "$(command -v apt-get)" ]; then
	apt-get update -y >> $LOG 2>&1
	apt-get install -y cron curl gzip >> $LOG 2>&1
	service cron start >> $LOG 2>&1

	# Check if perl available or not
	if ! type "perl" >> $LOG 2>&1; then
		apt-get install -y perl >> $LOG 2>&1
	fi

	# Check if unzip available or not
	if ! type "unzip" >> $LOG 2>&1; then
		apt-get install -y unzip >> $LOG 2>&1
	fi

	# Check if curl available or not
	if ! type "curl" >> $LOG 2>&1; then
		apt-get install -y curl >> $LOG 2>&1
	fi
fi

# ArchLinux
if [ -n "$(command -v pacman)" ]; then
	pacman -Sy  >> $LOG 2>&1
	pacman -S --noconfirm cronie curl gzip >> $LOG 2>&1
	systemctl start cronie >> $LOG 2>&1
	systemctl enable cronie >> $LOG 2>&1

	# Check if perl available or not
	if ! type "perl" >> $LOG 2>&1; then
		pacman -S --noconfirm perl >> $LOG 2>&1
	fi

	# Check if unzip available or not
	if ! type "unzip" >> $LOG 2>&1; then
		pacman -S --noconfirm unzip >> $LOG 2>&1
	fi

	# Check if curl available or not
	if ! type "curl" >> $LOG 2>&1; then
		pacman -S --noconfirm curl >> $LOG 2>&1
	fi
fi

# OpenSuse
if [ -n "$(command -v zypper)" ]; then
	zypper --non-interactive install cronie curl gzip >> $LOG 2>&1
	service cron start >> $LOG 2>&1

	# Check if perl available or not
	if ! type "perl" >> $LOG 2>&1; then
		zypper --non-interactive install perl >> $LOG 2>&1
	fi

	# Check if unzip available or not
	if ! type "unzip" >> $LOG 2>&1; then
		zypper --non-interactive install unzip >> $LOG 2>&1
	fi

	# Check if curl available or not
	if ! type "curl" >> $LOG 2>&1; then
		zypper --non-interactive install curl >> $LOG 2>&1
	fi
fi

# Gentoo
if [ -n "$(command -v emerge)" ]; then

	# Check if crontab is present or not available or not
	if ! type "crontab" >> $LOG 2>&1; then
		emerge cronie >> $LOG 2>&1
		/etc/init.d/cronie start >> $LOG 2>&1
		rc-update add cronie default >> $LOG 2>&1
 	fi

	# Check if perl available or not
	if ! type "perl" >> $LOG 2>&1; then
		emerge perl >> $LOG 2>&1
	fi

	# Check if unzip available or not
	if ! type "unzip" >> $LOG 2>&1; then
		emerge unzip >> $LOG 2>&1
	fi

	# Check if curl available or not
	if ! type "curl" >> $LOG 2>&1; then
		emerge net-misc/curl >> $LOG 2>&1
	fi

	# Check if gzip available or not
	if ! type "gzip" >> $LOG 2>&1; then
		emerge gzip >> $LOG 2>&1
	fi
fi

# Slackware
if [ -f "/etc/slackware-version" ]; then

	if [ -n "$(command -v slackpkg)" ]; then

		# Check if crontab is present or not available or not
		if ! type "crontab" >> $LOG 2>&1; then
			slackpkg -dialog=off -batch=on -default_answer=y install dcron >> $LOG 2>&1
		fi

		# Check if perl available or not
		if ! type "perl" >> $LOG 2>&1; then
			slackpkg -dialog=off -batch=on -default_answer=y install perl >> $LOG 2>&1
		fi

		# Check if unzip available or not
		if ! type "unzip" >> $LOG 2>&1; then
			slackpkg -dialog=off -batch=on -default_answer=y install infozip >> $LOG 2>&1
		fi

		# Check if curl available or not
		if ! type "curl" >> $LOG 2>&1; then
			slackpkg -dialog=off -batch=on -default_answer=y install curl >> $LOG 2>&1
		fi

		# Check if gzip available or not
		if ! type "gzip" >> $LOG 2>&1; then
			slackpkg -dialog=off -batch=on -default_answer=y install gzip >> $LOG 2>&1
		fi

	else
		echo "Please install slackpkg and re-run installation."
		exit 1;
	fi
fi

# Is Cron available?
if [ ! -n "$(command -v crontab)" ]; then
	echo -e "${RED}✗ Error: Cron is required but we could not install it.${NC}"
	echo -e "${RED}→ Exiting installer${NC}"
	exit 1;
fi

# Is CURL available?
if [  ! -n "$(command -v curl)" ]; then
	echo -e "${RED}✗ Error: CURL is required but we could not install it.${NC}"
	echo -e "${RED}→ Exiting installer${NC}"
	exit 1;
fi

# Check for existing installation
existing_install=0
existing_cron=0

if [ -f /opt/uptimematrix/agent.sh ]; then
	existing_install=1
fi

if id "uptimematrixagent" &>/dev/null; then
	existing_cron=1
fi

if [ $existing_install -eq 1 ] || [ $existing_cron -eq 1 ]; then
	echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
	echo -e "${BOLD}${YELLOW}   Existing Installation Detected${NC}"
	echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
	echo " "

	if [ $existing_install -eq 1 ]; then
		echo -e "${CYAN}   Found: /opt/uptimematrix/agent.sh${NC}"
	fi
	if [ $existing_cron -eq 1 ]; then
		echo -e "${CYAN}   Found: User 'uptimematrixagent' with cron job${NC}"
	fi
	echo " "
	echo -e "${WHITE}What would you like to do?${NC}"
	echo " "
	echo -e "${GREEN}   [1] Repair / Re-install agent${NC}"
	echo -e "${RED}   [2] Remove / Uninstall agent${NC}"
	echo -e "${YELLOW}   [3] Cancel and exit${NC}"
	echo " "

	read -n 1 -p "Enter your choice (1/2/3): " choice
	echo ""

	case "$choice" in
		1)
			echo " "
			echo -e "${CYAN}➜ Proceeding with repair/re-install...${NC}"
			echo " "

			# Remove existing installation
			rm -rf /opt/uptimematrix >> $LOG 2>&1
			crontab -r -u uptimematrixagent >> $LOG 2>&1
			userdel uptimematrixagent >> $LOG 2>&1
			groupdel uptimematrixagent >> $LOG 2>&1
			echo -e "${GREEN}✓ Previous installation removed${NC}"
			;;
		2)
			echo " "
			echo -e "${CYAN}➜ Removing UptimeMatrix Agent...${NC}"
			echo " "

			# Remove crontab
			if [ $existing_cron -eq 1 ]; then
				crontab -r -u uptimematrixagent >> $LOG 2>&1
				echo -e "${GREEN}✓ Cron job removed${NC}"
			fi

			# Remove user
			if id "uptimematrixagent" &>/dev/null; then
				userdel uptimematrixagent >> $LOG 2>&1
				groupdel uptimematrixagent >> $LOG 2>&1
				echo -e "${GREEN}✓ System user removed${NC}"
			fi

			# Remove installation directory
			if [ $existing_install -eq 1 ]; then
				rm -rf /opt/uptimematrix >> $LOG 2>&1
				echo -e "${GREEN}✓ Installation files removed${NC}"
			fi

			echo " "
			echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
			echo -e "${BOLD}${GREEN}   ✓ UptimeMatrix Agent Removed Successfully${NC}"
			echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
			echo " "
			echo -e "${CYAN}Thank you for using UptimeMatrix!${NC}"
			echo " "
			exit 0
			;;
		*)
			echo " "
			echo -e "${YELLOW}Installation cancelled.${NC}"
			exit 0
			;;
	esac
fi

# Check gateway connection
echo -e "${CYAN}➜ Checking gateway connection to $GATEWAY...${NC}"

# Determine if using HTTPS
is_https=0
if [[ "$GATEWAY" == https://* ]]; then
	is_https=1
fi

if curl --output /dev/null --silent --head --fail "$GATEWAY"; then
	if [ $is_https -eq 1 ]; then
		echo -e "${GREEN}✓ SSL Connection established to $GATEWAY${NC}"
	else
		echo -e "${GREEN}✓ Connection established to $GATEWAY (HTTP - less secure)${NC}"
	fi
	### Install ###
	echo -e "${CYAN}➜ Downloading agent...${NC}"
	mkdir -p /opt/uptimematrix >> $LOG 2>&1
	wget --no-check-certificate -O /opt/uptimematrix/agent.sh https://raw.githubusercontent.com/uptime-matrix/server-agent/refs/heads/main/agent.sh >> $LOG 2>&1

	echo "$SERVER_KEY" > /opt/uptimematrix/serverkey
	echo "$GATEWAY" > /opt/uptimematrix/gateway
	echo -e "${GREEN}✓ Agent downloaded successfully${NC}"
else
	if [ $is_https -eq 1 ]; then
		echo -e "${YELLOW}⚠ Warning: Cannot establish SSL connection to $GATEWAY${NC}"
		echo " "
		echo -e "${YELLOW}Maybe you are using an old OS which cannot establish SSL connection.${NC}"
		echo -e "${YELLOW}But you can still continue monitoring using HTTP protocol (less secure).${NC}"
		echo " "
		read -n 1 -p "$(echo -e ${WHITE}Do you want to continue with HTTP? [Y/n] ${NC})" reply;
		if [ ! "$reply" = "${reply#[Nn]}" ]; then
		   echo ""
		   echo -e "${RED}✗ Terminated UptimeMatrix agent installation.${NC}"
		   echo -e "${CYAN}If you think this is an error, please contact support.${NC}"
		   echo ""
		   exit 1;
		fi
		echo ""
		echo -e "${YELLOW}→ Continuing installation with HTTP protocol...${NC}"
		echo ""
		# Switch to HTTP
		GATEWAY="${GATEWAY/https:\/\//http:\/\/}"
		### Install ###
		echo -e "${CYAN}➜ Downloading agent...${NC}"
		mkdir -p /opt/uptimematrix
		wget --no-check-certificate -O /opt/uptimematrix/agent.sh https://raw.githubusercontent.com/uptime-matrix/server-agent/refs/heads/main/agent.sh
		echo "$SERVER_KEY" > /opt/uptimematrix/serverkey
		echo "$GATEWAY" > /opt/uptimematrix/gateway
		echo -e "${GREEN}✓ Agent downloaded successfully${NC}"
	else
		echo -e "${RED}✗ Error: Cannot connect to gateway: $GATEWAY${NC}"
		echo -e "${YELLOW}→ Check your network connection and try again${NC}"
		exit 1;
	fi
fi

# Did it download ?
if ! [ -f /opt/uptimematrix/agent.sh ]; then
	echo -e "${RED}✗ Error: Unable to download agent!${NC}"
	echo -e "${RED}→ Exiting installer${NC}"
	exit 1;
fi

echo -e "${CYAN}➜ Creating system user...${NC}"

useradd uptimematrixagent -r -d /opt/uptimematrix -s /bin/false >> $LOG 2>&1
groupadd uptimematrixagent >> $LOG 2>&1

# Disable cagefs for uptimematrix
if [ -f /usr/sbin/cagefsctl ]; then
	/usr/sbin/cagefsctl --disable uptimematrixagent >> $LOG 2>&1
fi

echo -e "${CYAN}➜ Setting permissions...${NC}"
# Modify user permissions
chown -R uptimematrixagent:uptimematrixagent /opt/uptimematrix && chmod -R 700 /opt/uptimematrix >> $LOG 2>&1

echo -e "${CYAN}➜ Configuring cron job...${NC}"
# Configure cron
crontab -u uptimematrixagent -l 2>/dev/null | { cat; echo "* * * * * bash /opt/uptimematrix/agent.sh > /opt/uptimematrix/cron.log 2>&1"; } | crontab -u uptimematrixagent -

echo -e "${GREEN}✓ Cron job configured${NC}"
echo " "

# Run agent once to send initial data
echo -e "${CYAN}➜ Sending initial server data...${NC}"
su -s /bin/bash -c "bash /opt/uptimematrix/agent.sh" uptimematrixagent >> $LOG 2>&1
if [ $? -eq 0 ]; then
	echo -e "${GREEN}✓ Initial data sent successfully${NC}"
else
	echo -e "${YELLOW}⚠ Warning: Could not send initial data (will retry via cron)${NC}"
fi

echo " "
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${GREEN}        ✓ Installation Completed Successfully!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo " "
echo -e "${BOLD}${WHITE}🚀 Next Steps:${NC}"
echo -e "${CYAN}   1.${NC} Check your server data at:"
echo -e "      ${BOLD}${BLUE}https://app.uptimematrix.com/servers${NC}"
echo " "
echo -e "${CYAN}   2.${NC} Agent is running and will send data every minute"
echo " "
echo -e "${WHITE}📋 Installation Log:${NC}"
echo -e "   ${CYAN}cat /tmp/uptimematrix.log${NC}"
echo " "
echo -e "${WHITE}🗑️  Uninstall Instructions:${NC}"
echo -e "${YELLOW}   sudo rm -rf /opt/uptimematrix && sudo crontab -r -u uptimematrixagent && sudo userdel uptimematrixagent${NC}"
echo -e "${CYAN}   Or re-run this installer and choose option [2] Remove${NC}"
echo " "
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${WHITE}   Thank you for choosing UptimeMatrix!${NC}"
echo -e "${CYAN}   🌐 www.uptimematrix.com${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo " "

# Attempt to delete this installer
if [ -f $0 ]; then
	rm -f $0
fi
