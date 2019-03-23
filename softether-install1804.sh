##----------------------------------------------------------------------------##
#  Based on https://gist.github.com/umardx/8c260b996600c09fed9e12420d3aa244    #
##----------------------------------------------------------------------------##

##!/usr/local/env bash
# Register digitalocean with free credit https://m.do.co/c/4879bb02d178
# Create vps with 5usd price
# Tested on Ubuntu 18.10, Debian 9.6
# How to...
# 1. Save this file as softether-installer.sh
# 2. chmod +x softether-installer.sh
# 3. Run bash file
# > ./softether-installer.sh
# Or just
# > bash softether-installer.sh
# 4. Init config vpnserver
# > cd /usr/local/vpnserver
# > sudo ./vpncmd
# Enter into local server/hub config
# > ServerPasswordSet {yourPassword}
# Then use SoftEther VPN Server Manager to mange your server

## Need to be root, or have sudo.
if [ "$(whoami)" != "root" ]; then
  SUDO=sudo
fi

# Update system
${SUDO} apt-get update && ${SUDO} apt-get -y upgrade

# Get build tools
${SUDO} apt-get -y install build-essential wget curl gcc make wget tzdata git libreadline-dev libncurses-dev libssl-dev zlib1g-dev iptables-persistent

# Define softether version
RTM=$(curl http://www.softether-download.com/files/softether/ | grep -o 'v[^"]*e' | grep rtm | tail -1)
IFS='-' read -r -a RTMS <<< "${RTM}"

# Get softether source
wget "http://www.softether-download.com/files/softether/${RTMS[0]}-${RTMS[1]}-${RTMS[2]}-${RTMS[3]}-${RTMS[4]}/Linux/SoftEther_VPN_Server/64bit_-_Intel_x64_or_AMD64/softether-vpnserver-${RTMS[0]}-${RTMS[1]}-${RTMS[2]}-${RTMS[3]}-linux-x64-64bit.tar.gz" -O /tmp/softether-vpnserver.tar.gz

# Extract softether source
${SUDO} tar -xzvf /tmp/softether-vpnserver.tar.gz -C /usr/local/

# Remove unused file
${SUDO} rm /tmp/softether-vpnserver.tar.gz

# Move to source directory
cd /usr/local/vpnserver

# Workaround for 18.04+
${SUDO} sed -i 's|OPTIONS=-O2|OPTIONS=-no-pie -O2|' Makefile

# Build softether
${SUDO} make i_read_and_agree_the_license_agreement

# Change file permission
${SUDO} chmod 0600 * && ${SUDO} chmod +x vpnserver && ${SUDO} chmod +x vpncmd

# Link binary files
${SUDO} ln -s /usr/local/vpnserver/vpnserver /usr/local/bin/vpnserver
${SUDO} ln -s /usr/local/vpnserver/vpncmd /usr/local/bin/vpncmd

# Add systemd service
cat <<EOF > ${SUDO} tee /lib/systemd/system/vpnserver.service
[Unit]
Description=SoftEther VPN Server
After=network.target
ConditionPathExists=!/usr/local/vpnserver/do_not_run

[Service]
Type=forking
ExecStart=/usr/local/vpnserver/vpnserver start
ExecStop=/usr/local/vpnserver/vpnserver stop
KillMode=process
Restart=on-failure
WorkingDirectory=/usr/local/vpnserver
# Hardening
PrivateTmp=yes
ProtectHome=yes
ProtectSystem=full
ReadOnlyDirectories=/
ReadWriteDirectories=-/usr/local/vpnserver
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_BROADCAST CAP_NET_RAW CAP_SYS_NICE CAP_SYS_ADMIN CAP_SETUID

[Install]
WantedBy=multi-user.target
Alias=vpnserver.service
EOF

# Act as router
echo "net.ipv4.ip_forward = 1" | ${SUDO} tee -a /etc/sysctl.conf

# Tune Kernel
echo "net.ipv4.ip_local_port_range = 1024 65535" | ${SUDO} tee -a /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control = bbr" | ${SUDO} tee -a /etc/sysctl.conf
echo "net.core.default_qdisc = fq_codel" | ${SUDO} tee -a /etc/sysctl.conf
${SUDO} sysctl -p

# Reload service
${SUDO} systemctl daemon-reload
# Enable service
${SUDO} systemctl enable vpnserver
# Start service
${SUDO} systemctl restart vpnserver

# Set the password to management to somepassword
sudo /usr/local/vpnserver/vpncmd 127.0.0.1:443 /SERVER /CMD ServerPasswordSet somepassword

exit 0
