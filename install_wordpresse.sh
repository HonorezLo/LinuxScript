#!/bin/bash

#################################################### <  C O N F I G U R A B L E    > #############################################################

USERNAME="vagrant"

LIST_PACKAGES="unzip mariadb-client python-mysqldb mariadb-server curl fping git graphviz imagemagick nmap python-memcache net-tools mtr-tiny rrdtool whois acl libapache2-mod-php7.3 php7.3-cli php7.3-curl php7.3-gd php7.3-json php7.3-mbstring php7.3-mysql php7.3-xml php7.3-zip apache2 composer"
SERVER_NAME="192.168.33.10"

USER_WORDPRESS="vagrant"
PASS_WORDPRESS="vagrant"

DB_USER="vagrant"
DB_PASS="vagrant"


############################################################################################################################################################
############################################################################################################################################################


if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi


function top {
    clear
    echo -e "\n*----------------------------------------------------------------------*"
    echo -e "|   I N S T A L L   W O R D P R E S S    S E R V E R                   |"
    echo -e "*----------------------------------------------------------------------*\n"
}

#################################################### <  I N S T A L L   D E P E N D A N C Y   > #############################################################

function update {
	top
    sudo apt-get --yes --force-yes update
    sudo apt-get --yes --force-yes upgrade
    sudo apt-get --yes --force-yes dist-upgrade
}

function php_maj {
    top
    echo -e "\n*-------------------------------------*"
    echo -e "|     I N S T A L L   P H P  7.3      |"
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
  mysql -u root -p$DB_PASS -e "CREATE DATABASE wordpressdb CHARACTER SET utf8 COLLATE utf8_unicode_ci;"
  mysql -u root -p$DB_PASS -e "CREATE USER 'wordpress'@'localhost' IDENTIFIED BY 'wordpress';"
  mysql -u root -p$DB_PASS -e "GRANT ALL PRIVILEGES ON wordpressdb.* TO 'wordpress'@'localhost';"
  mysql -u root -p$DB_PASS -e "FLUSH PRIVILEGES;"
  
  sudo /etc/init.d/mysql restart
  
}


function config_wordpress {

    echo -e "\n*------------------------------------------*"
    echo -e "|    I N S T A L L   W O R D P R E S S     |"
    echo -e "*------------------------------------------*\n"
   	cd /var/www/html/
   	sudo curl -O https://wordpress.org/latest.tar.gz
   	sudo tar -xvf latest.tar.gz
   	sudo rm -v latest.tar.gz
   	echo -e "\n*--------------------------------------------------------*"
    echo -e "|    S E T  P E R M I S S I O N    W O R D P R E S S     |"
    echo -e "*--------------------------------------------------------*\n"
	sudo chown -R www-data:www-data /var/www/html/wordpress
   	sudo find /var/www/html/wordpress/ -type d -exec chmod 750 {} \;
	sudo find /var/www/html/wordpress/ -type f -exec chmod 640 {} \;
    
    cd wordpress
    sudo mv wp-config-sample.php wp-config.php
    
    echo -e "\n*--------------------------------------------------------*"
    echo -e "|    S E T  P E R M I S S I O N    W O R D P R E S S     |"
    echo -e "*--------------------------------------------------------*\n"
    SECURE=$(sudo curl -s https://api.wordpress.org/secret-key/1.1/salt/)
    
    
    echo "
<?php
/**
 * The base configuration for WordPress
 *
 * The wp-config.php creation script uses this file during the
 * installation. You don't have to use the web site, you can
 * copy this file to "wp-config.php" and fill in the values.
 *
 * This file contains the following configurations:
 *
 * * MySQL settings
 * * Secret keys
 * * Database table prefix
 * * ABSPATH
 *
 * @link https://codex.wordpress.org/Editing_wp-config.php
 *
 * @package WordPress
 */

// ** MySQL settings - You can get this info from your web host ** //
/** The name of the database for WordPress */
define( 'DB_NAME', 'wordpressdb' );

/** MySQL database username */
define( 'DB_USER', 'wordpress' );

/** MySQL database password */
define( 'DB_PASSWORD', 'wordpress' );

/** MySQL hostname */
define( 'DB_HOST', 'localhost' );

/** Database Charset to use in creating database tables. */
define( 'DB_CHARSET', 'utf8' );

/** The Database Collate type. Don't change this if in doubt. */
define( 'DB_COLLATE', '' );

/**#@+
 * Authentication Unique Keys and Salts.
 *
 * Change these to different unique phrases!
 * You can generate these using the {@link https://api.wordpress.org/secret-key/1.1/salt/ WordPress.org secret-key service}
 * You can change these at any point in time to invalidate all existing cookies. This will force all users to have to log in again.
 *
 * @since 2.6.0
 */
 
$SECURE

/**#@-*/

/**
 * WordPress Database Table prefix.
 *
 * You can have multiple installations in one database if you give each
 * a unique prefix. Only numbers, letters, and underscores please!
 */
$table_prefix = 'wp_';

/**
 * For developers: WordPress debugging mode.
 *
 * Change this to true to enable the display of notices during development.
 * It is strongly recommended that plugin and theme developers use WP_DEBUG
 * in their development environments.
 *
 * For information on other constants that can be used for debugging,
 * visit the Codex.
 *
 * @link https://codex.wordpress.org/Debugging_in_WordPress
 */
define( 'WP_DEBUG', false );

/* That's all, stop editing! Happy publishing. */

/** Absolute path to the WordPress directory. */
if ( ! defined( 'ABSPATH' ) ) {
	define( 'ABSPATH', dirname( __FILE__ ) . '/' );
}

/** Sets up WordPress vars and included files. */
require_once( ABSPATH . 'wp-settings.php' );    

" > wp-config.php
   	
    echo -e "\n*----------------------------------------*"
    echo -e "| C O N F I G   P H P   T I M E Z O N E  |"
    echo -e "*----------------------------------------*\n"
    
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
	echo "ServerName $SERVER_NAME" >> /etc/apache2/apache2.conf
   	
echo "
<VirtualHost *:80>
    DocumentRoot /var/www/html/wordpress/
    ServerName $SERVER_NAME

    <Directory "/var/www/html/wordpress/">
        AllowOverride All
    </Directory>
</VirtualHost>" > /etc/apache2/sites-available/wordpress.conf


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
    sudo a2ensite wordpress.conf
    sudo a2enmod rewrite
		
	sudo apache2ctl configtest
    sudo /etc/init.d/apache2 restart
}

function create_sumary {

cd /home/vagrant

echo "

# INFOS LIST

## TODO
        - create your own user
        - set ip static
        - modify your ip into VHOST


## INFOS WORDPRESS

user:
    - $USER_WORDPRESS

password:
    - $PASS_WORDPRESS

## INFOS DATABASE

user:
    - root
    - $DB_USER

password:
    - vagrant
    - $DB_PASS " > Readme.md
    
}


function show_infos {
	
	echo -e "\n*-----------------------------------------------*"
    echo -e "|    F I N I S H E D   I N S T A L L A T I O N  |"
    echo -e "*-----------------------------------------------*\n"
	echo -e "[V] HTTPD (apache) Installed / configured"
	echo -e "[V] Database (mysqld) Installed / configured"
	echo -e "[V] WORDPRESS Installed"
	echo -e "[INFOS] Please visit http://$SERVER_NAME/"
	echo -e "[INFOS] You can add a device by visiting http://$SERVER_NAME/addhost"
	echo -e "[INFOS] Create your Dashboard and let's play it\n"
	
}

############################################################################################################################################################
############################################################################################################################################################

function main {
    php_maj
    install_deps
    config_database
    config_wordpress
    create_sumary
		
    sudo systemctl status mysql
    sudo systemctl status apache2

    show_infos
}

main
