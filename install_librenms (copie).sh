#!/bin/bash

#################################################### <  C O N F I G U R A B L E    > #############################################################

LIST_PACKAGES="ca-certificats apt-transport-https unifi openvpn easy-rsa

"
DNS_PRIMARY="1.1.1.1"
DNS_SECONDARY="8.8.8.8"


############################################################################################################################################################
############################################################################################################################################################


if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

function top {
    clear
    echo -e "*----------------------------------------------------------------*"
    echo -e "|   I N S T A L L   U N I F I    S E R V E R                     |"
    echo -e "*----------------------------------------------------------------*\n"
}

#################################################### <  I N S T A L L   D E P E N D A N C Y   > #############################################################

function update {
    sudo apt-get --yes --force-yes update
    sudo apt-get --yes --force-yes upgrade
    sudo apt-get --yes --force-yes dist-upgrade
}

function maj_unifi {
    top
    echo -e "\n*-------------------------------------*"
    echo -e "|     I N S T A L L   U N I F I       |"
    echo -e "*-------------------------------------*\n"
    sudo wget -O /etc/apt/trusted.gpg.d/unifi-repo.gpg https://dl.ui.com/unifi/unifi-repo.gpg 
		echo 'deb https://www.ui.com/downloads/unifi/debian stable ubiquiti' | sudo tee /etc/apt/sources.list.d/100-ubnt-unifi.list
    update
}

function install_deps {
    for pack in $LIST_PACKAGES
    do
        top
        sudo apt -y install $pack
    done
}


############################################################################################################################################################
############################################################################################################################################################

#################################################### <  I N S T A L L   L A M P   > #############################################################


function config_openvpn {
  top
  
  echo -e "\n*-------------------------------------------*"
  echo -e "|     I N I T   T H E   O P E N V P N       |"
  echo -e "*-------------------------------------------*\n"


	echo -e "\nBackup of OpenVPN Server\n"
	sudo cp -avr /etc/openvpn/server.conf /etc/openvpn/server.conf.backup
	
	echo "
	# OpenVPN Port, Protocol and the Tun
port 1194
proto udp
dev tun0

# OpenVPN Server Certificate - CA, server key and certificate
ca /etc/openvpn/server/ca.crt
cert /etc/openvpn/server/openvpn.crt
key /etc/openvpn/server/openvpn.key

#DH and CRL key
dh /etc/openvpn/server/dh.pem
crl-verify /etc/openvpn/server/crl.pem

# Network Configuration - Internal network
# Redirect all Connection through OpenVPN Server
server 10.10.1.0 255.255.255.0
push "redirect-gateway def1"

# Access Intnernal Network
# route 192.168.1.0 255.255.255.0
push "route 192.168.1.0 255.255.255.0"

# Using the DNS from https://dns.watch
push "dhcp-option DNS 1.1.1.1"
push "dhcp-option DNS 8.8.8.8"

#Enable multiple client to connect with same Certificate key
duplicate-cn

# TLS Security
cipher AES-256-CBC
tls-version-min 1.2
tls-cipher TLS-DHE-RSA-WITH-AES-256-GCM-SHA384:TLS-DHE-RSA-WITH-AES-256-CBC-SHA256:TLS-DHE-RSA-WITH-AES-128-GCM-SHA256:TLS-DHE-RSA-WITH-AES-128-CBC-SHA256
auth SHA512
auth-nocache

# Other Configuration
keepalive 20 60
persist-key
persist-tun
comp-lzo yes
daemon
user nobody
group nogroup

# OpenVPN Log
log-append /var/log/openvpn.log
verb 3 " > /etc/openvpn/server.conf



















  echo -e "\nSecure the database\n"

sudo mysql_secure_installation << EOF
y
$DB_PASS
$DB_PASS
y
y
y
y
EOF

  echo -e "\nActivation du Service MySQL\n"
  sudo systemctl enable mysqld
  sudo /etc/init.d/mysql restart

  echo -e "\n*-------------------------------------------------------*"
  echo -e "|   M O D I F Y  T H E  C O N F I G   D A T A B A S E   |"
  echo -e "*-------------------------------------------------------*\n"

  echo -e "\nConfigure the database config\n"
  sudo cp -avr /etc/mysql/mariadb.conf.d/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf.backup
  
  
  sudo /etc/init.d/mysql restart
  

  echo -e "\n*-------------------------------------------*"
  echo -e "|   C R E A T E   T H E   D A T A B A S E   |"
  echo -e "*-------------------------------------------*\n"
  mysql -u root -p$DB_PASS -e "CREATE DATABASE librenms CHARACTER SET utf8 COLLATE utf8_unicode_ci;"
  mysql -u root -p$DB_PASS -e "CREATE USER 'librenms'@'localhost' IDENTIFIED BY 'vagrant';"
  mysql -u root -p$DB_PASS -e "GRANT ALL PRIVILEGES ON librenms.* TO 'librenms'@'localhost';"
  mysql -u root -p$DB_PASS -e "FLUSH PRIVILEGES;"
  sudo /etc/init.d/mysql restart
}




function show_infos {
	
	echo -e "\n*-----------------------------------------------*"
  echo -e "|    F I N I S H E D   I N S T A L L A T I O N  |"
  echo -e "*-----------------------------------------------*\n"
	echo -e "[V] UniFI Installed / configured"
	echo -e "[V] OpenVPN Installed / Configured"
	echo -e "[V] Generate OpenVPN Client Config"
	echo -e "[INFOS] Please visit https://$SERVER_NAME/:8443"
	echo -e "[INFOS] Add your Ubiquiti Devices and let's play it"
}

############################################################################################################################################################
############################################################################################################################################################

function main {
    maj_unifi
    install_deps
    
    sudo systemctl enable unifi
    sudo systemctl start unifi
    
    config_openvpn
    
    
    sudo systemctl status mysql
    sudo systemctl status apache2
    sudo systemctl status snmpd


		echo -e "\n*----------------------------------------*"
  	echo -e "|    T E S T   S N M P D   A G E N T     |"
  	echo -e "*----------------------------------------*\n"
    snmpwalk -v3 -a SHA -A $SNMP_PASSWD_RW -x AES -X $SNMP_PASSWD_RW -l authPriv -u $SNMPUSER_RW  $SERVER_NAME | head -10
    show_infos
}

main
