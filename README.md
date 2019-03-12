# odoo12-auto-install

# create git-info.conf file to config your custom addons source
path=git.path (remove http:\\ or https:\\)
user=git_user_name
password=git_password
branch=git_branch

# add permission for odoo_install.sh
sudo chmod +x odoo_install.sh

# run install
./odoo_install.sh
