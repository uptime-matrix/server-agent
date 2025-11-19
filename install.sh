#!/bin/bash

# Set environment
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Clear the screen
clear

# GATEWAY=$2
LOG=/tmp/uptimematrix.log

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

# Are we running as root
if [ $(id -u) != "0" ]; then
	echo -e "${RED}✗ Error: UptimeMatrix Agent installer needs to be run with root priviliges${NC}"
	echo -e "${YELLOW}→ Try again with root privilileges${NC}"
	exit 1;
fi

# Is the server key parameter given ?
if [ $# -lt 1 ]; then
	echo -e "${RED}✗ Error: The server key parameter is missing${NC}"
	echo -e "${YELLOW}→ Usage: bash install.sh <server-key>${NC}"
	echo -e "${RED}→ Exiting installer${NC}"
	exit 1;
fi

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

# Remove previous installation
if [ -f /opt/uptimematrix/agent.sh ]; then
	echo -e "${YELLOW}⚠ Found previous installation, removing...${NC}"
	# Remove folder
	rm -rf /opt/uptimematrix
	# Remove crontab
	crontab -r -u uptimematrixagent >> $LOG 2>&1
	# Remove user
	userdel uptimematrixagent >> $LOG 2>&1
	echo -e "${GREEN}✓ Previous installation removed${NC}"
fi

# Check if the system can establish SSL connection
echo -e "${CYAN}➜ Checking SSL connection...${NC}"
if curl --output /dev/null --silent --head --fail "https://hop.uptimematrix.com"; then
	echo -e "${GREEN}✓ SSL Connection established${NC}"
	### Install ###
	echo -e "${CYAN}➜ Downloading agent...${NC}"
	mkdir -p /opt/uptimematrix >> $LOG 2>&1
	wget --no-check-certificate -O /opt/uptimematrix/agent.sh https://raw.githubusercontent.com/uptime-matrix/server-agent/refs/heads/main/agent.sh >> $LOG 2>&1

	echo "$1" > /opt/uptimematrix/serverkey
	echo "https://hop.uptimematrix.com" > /opt/uptimematrix/gateway
	echo -e "${GREEN}✓ Agent downloaded successfully${NC}"
else
	echo -e "${YELLOW}⚠ Warning: Cannot establish SSL connection${NC}"
	echo " "
	echo -e "${YELLOW}Maybe you are using an old OS which cannot establish SSL connection.${NC}"
	echo -e "${YELLOW}But you can still continue monitoring using HTTP protocol (less secure).${NC}"
	echo " "
	read -n 1 -p "$(echo -e ${WHITE}Do you want to continue? [Y/n] ${NC})" reply;
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
	### Install ###
	echo -e "${CYAN}➜ Downloading agent...${NC}"
        mkdir -p /opt/uptimematrix
        #wget --no-check-certificate -O /opt/uptimematrix/agent.sh http://hop.uptimematrix.com/assets/agent.sh
	wget --no-check-certificate -O /opt/uptimematrix/agent.sh https://raw.githubusercontent.com/uptime-matrix/server-agent/refs/heads/main/agent.sh
        echo "$1" > /opt/uptimematrix/serverkey
        echo "http://hop.uptimematrix.com" > /opt/uptimematrix/gateway
	echo -e "${GREEN}✓ Agent downloaded successfully${NC}"
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
echo -e "${YELLOW}   rm -rf /opt/uptimematrix && crontab -r -u uptimematrixagent && userdel uptimematrixagent${NC}"
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
