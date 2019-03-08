#!/bin/bash
################################################################################
# Script for installing Odoo on Ubuntu 14.04, 15.04, 16.04 and 18.04 (could be used for other version too)
# Author: Yenthe Van Ginneken
#-------------------------------------------------------------------------------
# This script will install Odoo on your Ubuntu 16.04 server. It can install multiple Odoo instances
# in one Ubuntu because of the different xmlrpc_ports
#-------------------------------------------------------------------------------
# Make a new file:
# sudo nano odoo-install.sh
# Place this content in it and then make the file executable:
# sudo chmod +x odoo-install.sh
# Execute the script to install Odoo:
# ./odoo-install
################################################################################

OE_USER="odoo"
OE_HOME="/$OE_USER"
OE_HOME_EXT="/$OE_USER/${OE_USER}-server"
# The default port where this Odoo instance will run under (provided you use the command -c in the terminal)
# Set to true if you want to install it, false if you don't need it or have it already installed.
INSTALL_WKHTMLTOPDF="True"
# Set the default Odoo port (you still have to use -c /etc/odoo-server.conf for example to use this.)
OE_PORT="8069"
# Choose the Odoo version which you want to install. For example: 12.0, 11.0, 10.0 or saas-18. When using 'master' the master version will be installed.
# IMPORTANT! This script contains extra libraries that are specifically needed for Odoo 12.0
OE_VERSION="12.0"
# Set this to True if you want to install the Odoo enterprise version!
IS_ENTERPRISE="False"
# set the superadmin password
OE_SUPERADMIN="admin"
OE_CONFIG="${OE_USER}-server"

#Clone NTQ customs addons.
#Setup info
GIT_FILE="./git-info.conf"

if [ ! -f "$GIT_FILE" ]
then
    echo -e  "File '${GIT_FILE}' not found!"
    exit
fi

GIT_PATH=`awk -F"=" '/^path/ { print $2 }' $GIT_FILE`
GIT_USER=`awk -F"=" '/^user/ { print $2 }' $GIT_FILE`
GIT_PASSWORD=`awk -F"=" '/^password/ { print $2 }' $GIT_FILE`
GIT_BRANCH=`awk -F"=" '/^branch/ { print $2 }' $GIT_FILE`

if [ "$GIT_PATH" = "" ] || [ "$GIT_USER" = "" ]  || [ "$GIT_PASSWORD" = "" ]  || [ "$GIT_BRANCH" = "" ]; then
    echo -e  "Please set value on ${GIT_FILE} file!"
    exit
fi

FULL_PATH="https://${GIT_USER}:${GIT_PASSWORD}@${GIT_PATH}"

##
###  WKHTMLTOPDF download links
## === Ubuntu Trusty x64 & x32 === (for other distributions please replace these two links,
## in order to have correct version of wkhtmltox installed, for a danger note refer to
## https://www.odoo.com/documentation/8.0/setup/install.html#deb ):
WKHTMLTOX_X64=https://downloads.wkhtmltopdf.org/0.12/0.12.1/wkhtmltox-0.12.1_linux-trusty-amd64.deb
WKHTMLTOX_X32=https://downloads.wkhtmltopdf.org/0.12/0.12.1/wkhtmltox-0.12.1_linux-trusty-i386.deb

#--------------------------------------------------
# Update Server
#--------------------------------------------------
echo -e "\n---- Update Server ----"
# universe package is for Ubuntu 18.x
sudo add-apt-repository universe
sudo apt-get update
sudo apt-get upgrade -y

#--------------------------------------------------
# Install PostgreSQL Server
#--------------------------------------------------
echo -e "\n---- Install PostgreSQL Server ----"
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -sc)-pgdg main" > /etc/apt/sources.list.d/PostgreSQL.list'
sudo apt update
sudo apt-get install postgresql-11 -y

sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'postgres';"

echo -e "\n---- Creating the ODOO PostgreSQL User  ----"
sudo su - postgres -c "createuser -s $OE_USER" 2> /dev/null || true

#--------------------------------------------------
echo -e "\n---- Install tool packages ----"
sudo apt-get install wget git bzr gdebi-core -y
sudo apt-get install software-properties-common -y

# Install Dependencies
#--------------------------------------------------
echo -e "\n--- Installing Python 3 + pip3 --"
# sudo apt-get install python3.6 python3-pip -y
#install python 3.6:

sudo add-apt-repository ppa:jonathonf/python-3.6 -y
sudo apt-get update
sudo apt-get install python3.6 python3.6-dev python3.6-minimal python3.6-venv -y

wget https://bootstrap.pypa.io/get-pip.py
sudo python3.6 get-pip.py

echo -e "\n---- Install python packages ----"
sudo apt-get install libxml2-dev libxslt1-dev zlib1g-dev -y
sudo apt-get install libsasl2-dev libldap2-dev libssl-dev -y
sudo apt-get install python3-pypdf2 python3-dateutil python3-feedparser python-ldap python-libxslt1 python3-lxml python3-mako python3-openid python3-psycopg2 python-pybabel python-pychart python-pydot python-pyparsing python-reportlab python-simplejson python-tz python-vatnumber python-vobject python-webdav python-werkzeug python-xlwt python-yaml python-zsi python-docutils python-psutil python-mock python-unittest2 python-jinja2 python-pypdf python-decorator python-requests python3-passlib python-pil -y
sudo python3.6 -m pip install pypdf2 Babel passlib Werkzeug decorator python-dateutil pyyaml psycopg2 psycopg2-binary psutil html2text docutils lxml pillow reportlab ninja2 requests gdata XlsxWriter vobject python-openid pyparsing pydot mock mako Jinja2 ebaysdk feedparser xlwt psycogreen suds-jurko pytz pyusb greenlet xlrd chardet libsass

echo -e "\n---- Install python libraries ----"
# This is for compatibility with Ubuntu 16.04. Will work on 14.04, 15.04 and 16.04
sudo apt-get install python3-suds

echo -e "\n--- Install other required packages"
sudo apt-get install node-clean-css -y
sudo apt-get install node-less -y
sudo apt-get install python-gevent -y

#--------------------------------------------------
# Install Wkhtmltopdf if needed
#--------------------------------------------------
if [ $INSTALL_WKHTMLTOPDF = "True" ]; then
  echo -e "\n---- Install wkhtml and place shortcuts on correct place for ODOO 12 ----"
  #pick up correct one from x64 & x32 versions:
  if [ "`getconf LONG_BIT`" == "64" ];then
      _url=$WKHTMLTOX_X64
  else
      _url=$WKHTMLTOX_X32
  fi
  sudo wget $_url
  sudo gdebi --n `basename $_url`
  sudo ln -s /usr/local/bin/wkhtmltopdf /usr/bin
  sudo ln -s /usr/local/bin/wkhtmltoimage /usr/bin
else
  echo "Wkhtmltopdf isn't installed due to the choice of the user!"
fi
sudo rm wkhtmltox-*.deb

echo -e "\n---- Create ODOO system user ----"
sudo adduser --system --quiet --shell=/bin/bash --home=$OE_HOME --gecos 'ODOO' --group $OE_USER
#The user should also be added to the sudo'ers group.
sudo adduser $OE_USER sudo

echo -e "\n---- Create Log directory ----"
sudo rm /var/log/$OE_USER
sudo mkdir /var/log/$OE_USER
sudo chown $OE_USER:$OE_USER /var/log/$OE_USER

#--------------------------------------------------
# Install ODOO
#--------------------------------------------------
echo -e "\n==== Installing ODOO Server ===="
sudo git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/odoo $OE_HOME_EXT/
# Install
sudo python3.6 -m pip install -r $OE_HOME_EXT/requirements.txt
sudo python3.6 -m pip install -r $OE_HOME_EXT/doc/requirements.txt

if [ $IS_ENTERPRISE = "True" ]; then
    # Odoo Enterprise install!
    echo -e "\n--- Create symlink for node"
    sudo ln -s /usr/bin/nodejs /usr/bin/node
    sudo su $OE_USER -c "mkdir $OE_HOME/enterprise"
    sudo su $OE_USER -c "mkdir $OE_HOME/enterprise/addons"

    GITHUB_RESPONSE=$(sudo git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/enterprise "$OE_HOME/enterprise/addons" 2>&1)
    while [[ $GITHUB_RESPONSE == *"Authentication"* ]]; do
        echo "------------------------WARNING------------------------------"
        echo "Your authentication with Github has failed! Please try again."
        printf "In order to clone and install the Odoo enterprise version you \nneed to be an offical Odoo partner and you need access to\nhttp://github.com/odoo/enterprise.\n"
        echo "TIP: Press ctrl+c to stop this script."
        echo "-------------------------------------------------------------"
        echo " "
        GITHUB_RESPONSE=$(sudo git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/enterprise "$OE_HOME/enterprise/addons" 2>&1)
    done

    echo -e "\n---- Added Enterprise code under $OE_HOME/enterprise/addons ----"
    echo -e "\n---- Installing Enterprise specific libraries ----"
    sudo python3.6 -m pip install num2words ofxparse
    sudo apt-get install nodejs npm
    sudo npm install -g less
    sudo npm install -g less-plugin-clean-css
fi

sudo apt-get install nodejs npm -y
sudo npm install -g less -y
sudo npm install -g less-plugin-clean-css -y

#quangtv edit
sudo python3.6 -m pip install num2words ofxparse

echo -e "\n---- Create custom module directory ----"
sudo rm -rf $OE_HOME/custom #remove if exits

sudo su $OE_USER -c "mkdir $OE_HOME/custom"
sudo su $OE_USER -c "mkdir $OE_HOME/custom/addons"

sudo rm -rf $OE_HOME/custom/addons/*
sudo git clone --depth 1 --branch $GIT_BRANCH $FULL_PATH $OE_HOME/custom/addons/

sudo python3.6 -m pip install -r $OE_HOME/custom/addons/requirements.txt
sudo python3.6 -m pip uninstall docx

#install python-docx
sudo git clone https://github.com/python-openxml/python-docx.git $OE_HOME/python-docx/
python3.6 $OE_HOME/python-docx/setup.py install


echo -e "\n---- Setting permissions on home folder ----"
sudo chown -R $OE_USER:$OE_USER $OE_HOME/*

echo -e "* Create server config file"

sudo rm /etc/${OE_CONFIG}.conf
sudo touch /etc/${OE_CONFIG}.conf
echo -e "* Creating server config file"
sudo su root -c "printf '[options] \n; This is the password that allows database operations:\n' >> /etc/${OE_CONFIG}.conf"
sudo su root -c "printf 'admin_passwd = ${OE_SUPERADMIN}\n' >> /etc/${OE_CONFIG}.conf"
sudo su root -c "printf 'xmlrpc_port = ${OE_PORT}\n' >> /etc/${OE_CONFIG}.conf"
sudo su root -c "printf 'logfile = /var/log/${OE_USER}/${OE_CONFIG}.log\n' >> /etc/${OE_CONFIG}.conf"
if [ $IS_ENTERPRISE = "True" ]; then
    sudo su root -c "printf 'addons_path=${OE_HOME}/enterprise/addons,${OE_HOME_EXT}/addons\n' >> /etc/${OE_CONFIG}.conf"
else
    sudo su root -c "printf 'addons_path=${OE_HOME_EXT}/addons,${OE_HOME}/custom/addons\n' >> /etc/${OE_CONFIG}.conf"
fi
sudo chown $OE_USER:$OE_USER /etc/${OE_CONFIG}.conf
sudo chmod 640 /etc/${OE_CONFIG}.conf

echo -e "* Create startup file"
sudo su root -c "echo '#!/bin/sh' >> $OE_HOME_EXT/start.sh"
sudo su root -c "echo 'sudo -u $OE_USER $OE_HOME_EXT/openerp-server --config=/etc/${OE_CONFIG}.conf' >> $OE_HOME_EXT/start.sh"
sudo chmod 755 $OE_HOME_EXT/start.sh

#--------------------------------------------------
# Adding ODOO as a deamon (initscript)
#--------------------------------------------------

echo -e "* Create Odoo Service"
cat <<EOF > ~/$OE_CONFIG
[Unit]
Description=Odoo Open Source ERP and CRM
Requires=postgresql.service
After=network.target postgresql.service

[Service]
Type=simple
PermissionsStartOnly=true
SyslogIdentifier=odoo-server
User=odoo
Group=odoo
ExecStart=/usr/bin/python3.6 $OE_HOME_EXT/odoo-bin --config=/etc/${OE_CONFIG}.conf
WorkingDirectory=$OE_HOME
StandardOutput=journal+console

[Install]
WantedBy=multi-user.target
EOF

echo -e "* Security Odoo Service File"
sudo rm /lib/systemd/system/${OE_CONFIG}.service
sudo mv ~/$OE_CONFIG /lib/systemd/system/${OE_CONFIG}.service
sudo chmod 755 /lib/systemd/system/${OE_CONFIG}.service
sudo chown root: /lib/systemd/system/${OE_CONFIG}.service

echo -e "* Start ODOO on Startup"
sudo systemctl enable odoo-server
sudo journalctl -u odoo-server

echo -e "* Starting Odoo Service"
sudo su root -c "systemctl stop odoo-server && systemctl start odoo-server"

echo "-----------------------------------------------------------"
echo "Done! The Odoo server is up and running. Specifications:"
echo "Port: $OE_PORT"
echo "User service: $OE_USER"
echo "User PostgreSQL: $OE_USER"
echo "Code location: $OE_USER"
echo "Addons folder: $OE_USER/$OE_CONFIG/addons/"
echo "Start Odoo service: sudo systemctl start odoo-server"
echo "Stop Odoo service: sudo systemctl stop odoo-server"
echo "Restart Odoo service: sudo systemctl restart odoo-server"
echo "Odoo service status: sudo systemctl status odoo-server"
echo "-----------------------------------------------------------"
