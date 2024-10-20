#!/bin/bash

echo "VICIdial installation for Ubuntu 22.04 LTS with WebPhone (WebRTC/SIP.js)"

# Update and install necessary packages
sudo apt update && sudo apt upgrade -y
sudo apt install -y software-properties-common
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update
sudo apt install -y build-essential linux-headers-$(uname -r) subversion unzip libjansson-dev sqlite autoconf automake libxml2-dev libncurses5-dev libsqlite3-dev subversion

# Install MariaDB 10.6
sudo apt-key adv --fetch-keys 'https://mariadb.org/mariadb_release_signing_key.asc'
sudo add-apt-repository 'deb [arch=amd64] http://mariadb.mirror.liquidtelecom.com/repo/10.6/ubuntu jammy main'
sudo apt update
sudo apt install -y mariadb-server mariadb-client

# Install Apache, PHP, and other required packages
sudo apt install -y apache2 apache2-bin apache2-data libapache2-mod-php7.4 php7.4 php7.4-dev php7.4-mbstring php7.4-cli php7.4-common php7.4-json php7.4-mysql php7.4-readline sox lame screen libnet-telnet-perl php7.4-mysqli libasterisk-agi-perl libelf-dev autogen libtool shtool libdbd-mysql-perl libmysqlclient-dev libsrtp2-dev uuid-dev libssl-dev git curl wget

# Install Jansson
cd /usr/src/
wget http://www.digip.org/jansson/releases/jansson-2.14.tar.gz
tar -zxf jansson-2.14.tar.gz
cd jansson-2.14
./configure
make clean
make
make install 
ldconfig

# Install CPAN modules
sudo apt install -y cpanminus
sudo cpanm -f File::HomeDir File::Which CPAN::Meta::Requirements CPAN YAML MD5 Digest::MD5 Digest::SHA1 Bundle::CPAN DBI DBD::mysql Net::Telnet Time::HiRes Net::Server Switch Mail::Sendmail Unicode::Map Jcode Spreadsheet::WriteExcel OLE::Storage_Lite Proc::ProcessTable IO::Scalar Spreadsheet::ParseExcel Curses Getopt::Long Net::Domain Term::ReadKey Term::ANSIColor Spreadsheet::XLSX Spreadsheet::Read LWP::UserAgent HTML::Entities HTML::Strip HTML::FormatText HTML::TreeBuilder Time::Local MIME::Decoder Mail::POP3Client Mail::IMAPClient Mail::Message IO::Socket::SSL MIME::Base64 MIME::QuotedPrint Crypt::Eksblowfish::Bcrypt Crypt::RC4 Text::CSV Text::CSV_XS

# Install DAHDI
sudo apt install -y dahdi-linux dahdi-tools
sudo modprobe dahdi
sudo modprobe dahdi_dummy
sudo dahdi_cfg -vvv

# Install Asterisk
mkdir -p /usr/src/asterisk
cd /usr/src/asterisk
wget http://downloads.asterisk.org/pub/telephony/asterisk/asterisk-18-current.tar.gz
tar -xvzf asterisk-18-current.tar.gz
cd asterisk-18.*
./configure --libdir=/usr/lib --with-gsm=internal --enable-opus --enable-srtp --with-ssl --enable-asteriskssl --with-pjproject-bundled
make menuselect.makeopts
menuselect/menuselect --enable app_meetme --enable res_http_websocket --enable res_srtp menuselect.makeopts
make
make install
make samples

# Install VICIdial
mkdir -p /usr/src/astguiclient
cd /usr/src/astguiclient
svn checkout svn://svn.eflo.net:43690/agc_2-X/trunk
cd trunk

# Create MySQL databases and users
sudo mysql -e "CREATE DATABASE asterisk DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;"
sudo mysql -e "CREATE USER 'cron'@'localhost' IDENTIFIED BY '1234';"
sudo mysql -e "GRANT SELECT,INSERT,UPDATE,DELETE,LOCK TABLES on asterisk.* TO cron@'%' IDENTIFIED BY '1234';"
sudo mysql -e "CREATE USER 'custom'@'localhost' IDENTIFIED BY 'custom1234';"
sudo mysql -e "GRANT SELECT,INSERT,UPDATE,DELETE,LOCK TABLES on asterisk.* TO custom@'%' IDENTIFIED BY 'custom1234';"
sudo mysql -e "GRANT RELOAD ON *.* TO cron@'%';"
sudo mysql -e "GRANT RELOAD ON *.* TO custom@'%';"
sudo mysql -e "FLUSH PRIVILEGES;"

# Import VICIdial database schema
sudo mysql asterisk < /usr/src/astguiclient/trunk/extras/MySQL_AST_CREATE_tables.sql
sudo mysql asterisk < /usr/src/astguiclient/trunk/extras/first_server_install.sql
sudo mysql -e "USE asterisk; UPDATE servers SET asterisk_version='18.0';"

# Configure astguiclient.conf
echo "Configuring astguiclient.conf"
sudo tee /etc/astguiclient.conf > /dev/null << EOL
# Asterisk database
VARDB_server => localhost
VARDB_database => asterisk
VARDB_user => cron
VARDB_pass => 1234
VARDB_custom_user => custom
VARDB_custom_pass => custom1234
VARDB_port => 3306

# Asterisk version
AST_ver => 18.X

# Directories
PATHhome => /usr/share/astguiclient
PATHlogs => /var/log/astguiclient
PATHagi => /var/lib/asterisk/agi-bin
PATHweb => /var/www/html
PATHsounds => /var/lib/asterisk/sounds
PATHmonitor => /var/spool/asterisk/monitor
PATHDONEmonitor => /var/spool/asterisk/monitorDONE

# Server configuration
VARserver_ip => SERVER_IP
VARFTP_host => SERVER_IP
VARFTP_user => asterisk
VARFTP_pass => 1234
VARFTP_port => 21
VARFTP_dir => /var/lib/asterisk/sounds

# Recording configuration
VARserver_ip => SERVER_IP
VARREPORT_host => SERVER_IP
VARREPORT_user => asterisk
VARREPORT_pass => 1234
VARREPORT_port => 21
VARREPORT_dir => /var/www/html

# FastAGI configuration
VARfastagi_log_min_servers => 3
VARfastagi_log_max_servers => 16
VARfastagi_log_min_spare_servers => 2
VARfastagi_log_max_spare_servers => 8
VARfastagi_log_max_requests => 1000
VARfastagi_log_checkfordead => 30
VARfastagi_log_checkforwait => 60

# VICIDIAL configuration
VARactive_keepalives => 0
VARasterisk_version => 18.X
VARftp_host => 127.0.0.1
VARftp_user => asterisk
VARftp_pass => 1234
VARftp_port => 21
VARftp_dir => /var/lib/asterisk/sounds
VARhttp_path => http://SERVER_IP
EOL

# Replace SERVER_IP with actual IP
SERVER_IP=16.171.152.69
sed -i "s/SERVER_IP/$SERVER_IP/g" /etc/astguiclient.conf

# Install VICIdial
echo "Installing VICIdial"
perl install.pl

# Secure Asterisk Manager
sudo sed -i 's/0.0.0.0/127.0.0.1/g' /etc/asterisk/manager.conf

# Populate area codes
/usr/share/astguiclient/ADMIN_area_code_populate.pl

# Update server IP
/usr/share/astguiclient/ADMIN_update_server_ip.pl --old-server_ip=10.10.10.15 --new-server_ip=$SERVER_IP

# Install crontab
echo "Installing crontab"
wget -O /root/crontab-file https://raw.githubusercontent.com/isaqib23/vicidial-install-scripts/main/crontab
crontab /root/crontab-file

# Configure rc.local
echo "Configuring rc.local"
sudo tee /etc/rc.local > /dev/null << EOL
#!/bin/bash
/usr/share/astguiclient/start_asterisk_boot.pl
exit 0
EOL
sudo chmod +x /etc/rc.local
sudo systemctl enable rc-local
sudo systemctl start rc-local

echo "VICIdial installation completed. Please reboot your system."
