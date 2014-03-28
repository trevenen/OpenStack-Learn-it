#################### Mastering OpenStack Controller Install ####################

export DEBIAN_FRONTEND=noninteractive
export MYSQL_ROOT_PASS=openstack
export MYSQL_HOST=controller
export MYSQL_PASS=openstack

echo "mysql-server-5.5 mysql-server/root_password password $MYSQL_ROOT_PASS" | sudo debconf-set-selections
echo "mysql-server-5.5 mysql-server/root_password_again password $MYSQL_ROOT_PASS" | sudo debconf-set-selections
echo "mysql-server-5.5 mysql-server/root_password seen true" | sudo debconf-set-selections
echo "mysql-server-5.5 mysql-server/root_password_again seen true" | sudo debconf-set-selections

sudo apt-get update
sudo apt-get install -y ubuntu-cloud-keyring vim git ntp openssh-server
sudo echo "deb http://ubuntu-cloud.archive.canonical.com/ubuntu precise-updates/havana main" | sudo tee /etc/apt/sources.list.d/havana.list
sudo apt-get install python-software-properties -y
sudo apt-get update && apt-get upgrade -y

rm /etc/hosts

echo "127.0.0.1 localhost
172.16.0.10 controller.local controller
172.16.0.11 compute1.local compute1
" > /etc/hosts

# Install NTP while we are here
echo "ntpdate controller
hwclock -w" | sudo tee /etc/cron.daily/ntpdate
chmod a+x /etc/cron.daily/ntpdate

# MySQL install

sudo apt-get install -y mysql-client-core-5.5

################
# Nova Install #
################

sudo apt-get install -y nova-compute-kvm python-novaclient python-guestfs python-keystoneclient
sudo update-guestfs-appliance
sudo apt-get install -y nova-network

sudo chmod 0644 /boot/vmlinuz*

sudo rm /var/lib/nova/nova.sqlite

echo "
my_ip=172.16.0.11
vncserver_listen=0.0.0.0
vncserver_proxyclient_address=172.16.0.11
glance_host=controller
network_manager=nova.network.manager.FlatDHCPManager
firewall_driver=nova.virt.libvirt.firewall.IptablesFirewallDriver
network_size=254
allow_same_net_traffic=False
multi_host=True
send_arp_for_ha=True
share_dhcp_address=True
force_dhcp_release=True
flat_network_bridge=br100
flat_interface=eth2
public_interface=eth1
" >> /etc/nova/nova.conf

sudo sed -i 's#^auth_host.*#auth_host = controller#' /etc/nova/api-paste.ini
sudo sed -i 's#^admin_tenant_name.*#admin_tenant_name = service#' /etc/nova/api-paste.ini
sudo sed -i 's#^admin_user.*#admin_user = nova#' /etc/nova/api-paste.ini
sudo sed -i 's#^admin_password.*#admin_password = nova#' /etc/nova/api-paste.ini

service nova-compute restart

export CONTROLLER_HOST=172.16.0.10
export KEYSTONE_ENDPOINT=172.16.0.10
export GLANCE_HOST=${CONTROLLER_HOST}
export MYSQL_HOST=${CONTROLLER_HOST}
export KEYSTONE_ENDPOINT=${CONTROLLER_HOST}
export SERVICE_TENANT_NAME=service
export SERVICE_PASS=openstack
export ENDPOINT=${KEYSTONE_ENDPOINT}
export SERVICE_TOKEN=ADMIN
export SERVICE_ENDPOINT=http://${ENDPOINT}:35357/v2.0
export OS_AUTH_URL="http://${KEYSTONE_ENDPOINT}:5000/v2.0/"
export OS_TENANT_NAME=mastering
export OS_USERNAME=admin
export OS_PASSWORD=openstack

echo "export CONTROLLER_HOST=172.16.0.10
export KEYSTONE_ENDPOINT=172.16.0.10
export GLANCE_HOST=${CONTROLLER_HOST}
export MYSQL_HOST=${CONTROLLER_HOST}
export KEYSTONE_ENDPOINT=${CONTROLLER_HOST}
export SERVICE_TENANT_NAME=service
export SERVICE_PASS=openstack
export ENDPOINT=${KEYSTONE_ENDPOINT}
export SERVICE_TOKEN=ADMIN
export SERVICE_ENDPOINT=http://${ENDPOINT}:35357/v2.0
export OS_AUTH_URL="http://${KEYSTONE_ENDPOINT}:5000/v2.0/"
export OS_TENANT_NAME=mastering
export OS_USERNAME=admin
export OS_PASSWORD=openstack" | sudo tee /home/vagrant/.openrc

source /home/vagrant/.openrc
echo "source /home/vagrant/.openrc" >> ~/.bashrc


