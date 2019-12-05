#!/bin/bash

#################################################### <  C O N F I G U R A B L E    > #############################################################

USERNAME="vagrant"

LIST_PACKAGES="unzip mariadb-client python-mysqldb mariadb-server curl fping git graphviz imagemagick nmap python-memcache net-tools mtr-tiny rrdtool whois snmp snmpd acl libsnmp-dev libapache2-mod-php7.3 php7.3-cli php7.3-curl php7.3-gd php7.3-json php7.3-mbstring php7.3-mysql php7.3-snmp php7.3-xml php7.3-zip apache2 composer"
SERVER_NAME="192.168.33.10"

SNMPUSER_RW="vagrantRw"
SNMP_PASSWD_RW="Test123*"

SNMPUSER_RO="vagrantRo"
SNMP_PASSWD_RO="Test123*"

USER_LNMS="vagrant"
PASS_LMNS="vagrant"

DB_USER="vagrant"
DB_PASS="vagrant"

MAIL_ADDRESS="tonmail@gmail.com"
LOCATION="Belgium, Mons"

############################################################################################################################################################
############################################################################################################################################################


if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

function top {
    clear
    echo -e "*----------------------------------------------------------------------*"
    echo -e "|   I N S T A L L   L I B R E N M S    S E R V E R                     |"
    echo -e "*----------------------------------------------------------------------*\n"
}

#################################################### <  I N S T A L L   D E P E N D A N C Y   > #############################################################

function update {
    sudo apt-get --yes --force-yes update
    sudo apt-get --yes --force-yes upgrade
    sudo apt-get --yes --force-yes dist-upgrade
}

function php_maj {
    top
    echo -e "\n*-------------------------------------*"
    echo -e "|     I N S T A L L   P H P 7.3       |"
    echo -e "*-------------------------------------*\n"
    sudo apt-get --yes --force-yes install lsb-release apt-transport-https ca-certificates
    sudo wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
    echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/php7.3.list
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

function config_database {
  top
  echo -e "\n*-------------------------------------------*"
  echo -e "|     I N I T   T H E   D A T A B A S  E     |"
  echo -e "*-------------------------------------------*\n"

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

  echo "
[server]

[mysqld]
innodb_file_per_table=1
lower_case_table_names=0
user		= mysql
pid-file	= /var/run/mysqld/mysqld.pid
socket		= /var/run/mysqld/mysqld.sock
port		= 3306
basedir		= /usr
datadir		= /var/lib/mysql
tmpdir		= /tmp
lc-messages-dir	= /usr/share/mysql
skip-external-locking
bind-address		= 127.0.0.1
key_buffer_size		= 16M
max_allowed_packet	= 16M
thread_stack		= 192K
thread_cache_size   = 8
myisam_recover_options  = BACKUP
query_cache_limit	= 1M
query_cache_size    = 16M
log_error = /var/log/mysql/error.log
expire_logs_days	= 10
max_binlog_size     = 100M
character-set-server = utf8mb4
collation-server     = utf8mb4_general_ci

[embedded]

[mariadb]

[mariadb-10.1]

" > /etc/mysql/mariadb.conf.d/50-server.cnf
  
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


function config_php {

    echo -e "\n*------------------------------------------*"
    echo -e "|   C R E A T E   T H E  L I B R E N M S   |"
    echo -e "*------------------------------------------*\n"
    sudo useradd librenms -d /opt/librenms -M -r
    sudo usermod -a -G librenms www-data

    sudo chown -Rv $USERNAME:$USERNAME /opt
    cd /opt
    git clone https://github.com/librenms/librenms.git

    sudo chown -Rv librenms:librenms /opt/librenms
    sudo chmod -v 770 /opt/librenms
    sudo setfacl -d -m g::rwx /opt/librenms/rrd /opt/librenms/logs /opt/librenms/bootstrap/cache/ /opt/librenms/storage/
    sudo setfacl -R -m g::rwx /opt/librenms/rrd /opt/librenms/logs /opt/librenms/bootstrap/cache/ /opt/librenms/storage/

    echo -e "\n*-----------------------------------*"
    echo -e "| I  N S T A L L   P H P   L I B S  |"
    echo -e "*-----------------------------------*\n"
    cd /opt/librenms
    sudo -u librenms ./scripts/composer_wrapper.php install --no-dev

    sudo cp -avr /etc/php/7.3/cli/php.ini /etc/php/7.3/cli/php.ini.backup
    sudo cp -avr /etc/php/7.3/apache2/php.ini /etc/php/7.3/apache2/php.ini.backup

    sed 's#^;date\.timezone[[:space:]]=.*$#date.timezone = "Europe/Brussels"#' /etc/php/7.3/cli/php.ini.backup > /etc/php/7.3/cli/php.ini
    sed 's#^;date\.timezone[[:space:]]=.*$#date.timezone = "Europe/Brussels"#' /etc/php/7.3/apache2/php.ini.backup > /etc/php/7.3/apache2/php.ini


    echo -e "\n*----------------------------------------*"
    echo -e "| C O N F I G U R E   T H E   V H O S T  |"
    echo -e "*----------------------------------------*\n"
    sudo a2enmod php7.3
    sudo a2dismod mpm_event
    sudo a2enmod mpm_prefork

echo "
<VirtualHost *:80>
    DocumentRoot /opt/librenms/html/
    ServerName $SERVER_NAME
    AllowEncodedSlashes NoDecode

    <Directory "/opt/librenms/html/">
        Require all granted
        AllowOverride All
        Options FollowSymLinks MultiViews
    </Directory>
</VirtualHost>" > /etc/apache2/sites-available/librenms.conf


    sudo systemctl enable apache2
    sudo systemctl start apache2

    echo -e "\n*---------------------------------*"
    echo -e "| S E C U R I S E   A P A C H E   |"
    echo -e "*---------------------------------*\n"
    sudo cp -avr /etc/apache2/conf-available/security.conf /etc/apache2/conf-available/security.conf.backup
    
    echo "
ServerTokens Prod
ServerSignature Off
TraceEnable Off" > /etc/apache2/conf-available/security.conf 

    sudo a2dissite 000-default
    sudo a2ensite librenms.conf
    sudo a2enmod rewrite

    sudo /etc/init.d/apache2 restart
}

function config_snmp {

    echo -e "\n*----------------------------------------*"
    echo -e "|   C O N F I G U R E    S N M P D       |"
    echo -e "*----------------------------------------*\n"
    sudo curl -o /usr/bin/distro https://raw.githubusercontent.com/librenms/librenms-agent/master/snmp/distro
    sudo chmod +x /usr/bin/distro
    sudo /etc/init.d/snmpd restart

    sudo cp -avr /opt/librenms/librenms.nonroot.cron /etc/cron.d/librenms
    sudo cp -avr /opt/librenms/misc/librenms.logrotate /etc/logrotate.d/librenms

    sudo systemctl stop snmpd


    echo -e "\n*----------------------------------------*"
    echo -e "| M O D I F Y   C O N F I G  S N M P D   |"
    echo -e "*----------------------------------------*\n"
    echo -e "\nBackup SNMPD conf file\n"
    sudo cp -avr /etc/snmp/snmpd.conf /etc/snmp/snmpd.conf.backup

    echo "
agentAddress  udp:$SERVER_NAME:161

view   systemonly  included   .1.3.6.1.2.1.1
view   systemonly  included   .1.3.6.1.2.1.25.1

 rocommunity public  default    -V systemonly
 rocommunity6 public  default   -V systemonly


 rouser   authOnlyUser


sysLocation    $LOCATION
sysContact     Me $MAIL_ADDRESS
sysServices    72


proc  mountd
proc  ntalkd    4
proc  sendmail 10 1


disk       /     10000
disk       /var  5%
includeAllDisks  10%

load   12 10 5

 trapsink     localhost public


iquerySecName   internalUser       
rouser          internalUser


 extend    test1   /bin/echo  Hello, world!
 extend-sh test2   echo Hello, world! ; echo Hi there ; exit 35

 master          agentx" > /etc/snmp/snmpd.conf


    # add user readonly
    sudo net-snmp-create-v3-user -ro -A $SNMP_PASSWD_RW -a SHA -X $SNMP_PASSWD_RW -x AES $SNMPUSER_RW

    # add user read/write
    sudo net-snmp-create-v3-user -A $SNMP_PASSWD_RO -a SHA -X $SNMP_PASSWD_RO -x AES $SNMPUSER_RO

    sudo systemctl restart snmpd
    sudo systemctl enable snmpd
}

function create_sumary {
echo "
# INFOS LIST

## TODO
        - create your own user
        - set ip static
        - modify your ip into VHOST


## INFOS SNMPD

user:
    - $SNMPUSER_RW
    - $SNMPUSER_RO

password:
    - $SNMP_PASSWD_RW
    - $SNMP_PASSWD_RO

## INFOS LIBRENMS

user:
    - $USER_LNMS

password:
    - $PASS_LMNS

## INFOS DATABASE

user:
    - root
    - $DB_USER

password:
    - vagrant
    - $DB_PASS

## TEST SNMP

snmpwalk -v3 -a SHA -A "Test123*" -x AES -X "Test123*" -l authPriv -u "vagrantRw" 192.168.33.10 | head -10
" > Readme.md

}

############################################################################################################################################################
############################################################################################################################################################

function main {
    php_maj
    install_deps
    config_database
    config_php
    config_snmp
    cd /home/vagrant
    create_sumary

    sudo systemctl status mysql
    sudo systemctl status apache2
    sudo systemctl status snmpd

    echo "\nTest Snmpd Services\n"
    snmpwalk -v3 -a SHA -A $SNMP_PASSWD_RW -x AES -X $SNMP_PASSWD_RW -l authPriv -u $SNMPUSER_RW  $SERVER_NAME | head -10
}

main
