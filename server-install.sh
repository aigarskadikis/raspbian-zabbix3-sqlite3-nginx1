#!/bin/bash
#this code is tested un fresh 2016-03-18-raspbian-jessie-lite.img Raspberry Pi image
#sudo raspi-config -> extend partition -> reboot
#sudo su
#apt-get update -y && apt-get upgrade -y && apt-get install git -y
#git clone https://github.com/catonrug/raspbian-zabbix3-sqlite3-nginx1.git && cd raspbian-zabbix3-sqlite3-nginx1 && chmod +x agent-install.sh server-install.sh
#time ./server-install.sh

#update repositories and upgrade system
apt-get update -y && apt-get upgrade -y

#install zabbix server prerequisites
apt-get install php5 php5-dev php5-gd -y
apt-get install fping -y
apt-get install libiksemel-dev -y
apt-get install libxml2-dev -y
apt-get install libsnmp-dev -y
apt-get install libssh2-1-dev -y
apt-get install libopenipmi-dev -y
apt-get install libcurl4-openssl-dev -y

#install all neccesary packages to work with sqlite
apt-get install libsqlite3-dev sqlite3 php5-sqlite -y

#set up zabbix user and group
groupadd zabbix
useradd -g zabbix zabbix
mkdir -p /var/log/zabbix
chown -R zabbix:zabbix /var/log/zabbix
mkdir -p /var/zabbix/alertscripts
mkdir -p /var/zabbix/externalscripts
chown -R zabbix:zabbix /var/zabbix

#extract zabbix source
tar -vzxf zabbix-*.tar.gz -C ~

#create basic database
mkdir -p /var/lib/sqlite
cd ~/zabbix-*/database/sqlite3
sqlite3 /var/lib/sqlite/zabbix.db <schema.sql
sqlite3 /var/lib/sqlite/zabbix.db <images.sql
sqlite3 /var/lib/sqlite/zabbix.db <data.sql

#set permissions to database
chown -R zabbix:zabbix /var/lib/sqlite/
chmod 774 -R /var/lib/sqlite
chmod 664 /var/lib/sqlite/zabbix.db

#configure, compile and install zabbix server and agent 
cd ~/zabbix-*/
./configure --enable-server --enable-agent --with-sqlite3 --with-libcurl --with-libxml2 --with-ssh2 --with-net-snmp --with-openipmi --with-jabber
make install

#install zabbix server and agent service
cp ~/zabbix-*/misc/init.d/debian/* /etc/init.d/
update-rc.d zabbix-server defaults
update-rc.d zabbix-agent defaults

#configure zabbix server minimal must have settings
sed -i "s/^.*FpingLocation=.*$/FpingLocation=\/usr\/bin\/fping/" /usr/local/etc/zabbix_server.conf
sed -i "s/^.*AlertScriptsPath=.*$/AlertScriptsPath=\/var\/zabbix\/alertscripts/" /usr/local/etc/zabbix_server.conf
sed -i "s/^.*ExternalScripts=.*$/ExternalScripts=\/var\/zabbix\/externalscripts/" /usr/local/etc/zabbix_server.conf
sed -i "s/^LogFile=.*$/LogFile=\/var\/log\/zabbix\/zabbix_server.log/" /usr/local/etc/zabbix_server.conf
sed -i "s/^DBName=.*$/DBName=\/var\/lib\/sqlite\/zabbix.db/" /usr/local/etc/zabbix_server.conf

#install web frontend
apt-get php5-fpm libgd2-xpm libpcrecpp0 libxpm4 -y
apt-get nginx -y
mkdir -p /var/www/html/zabbix
cd ~/zabbix-*/frontends/php/
cp -a . /var/www/html/zabbix/

#set apache user to be owner of frontent
chown -R www-data:www-data /var/www

#set apache user as member of zabbix group
adduser www-data zabbix

#restart zabbix server
/etc/init.d/zabbix-server restart

#restart nginx service
service nginx restart
service php5-fpm restart
service fcgiwrap restart
