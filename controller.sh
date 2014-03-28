#################### Mastering OpenStack Controller Install ####################

# MySQL install preparation
export DEBIAN_FRONTEND=noninteractive
export MYSQL_ROOT_PASS=openstack
export MYSQL_HOST=0.0.0.0
export MYSQL_PASS=openstack

echo "mysql-server-5.5 mysql-server/root_password password $MYSQL_ROOT_PASS" | sudo debconf-set-selections
echo "mysql-server-5.5 mysql-server/root_password_again password $MYSQL_ROOT_PASS" | sudo debconf-set-selections
echo "mysql-server-5.5 mysql-server/root_password seen true" | sudo debconf-set-selections
echo "mysql-server-5.5 mysql-server/root_password_again seen true" | sudo debconf-set-selections
        
sudo apt-get update
sudo apt-get install -y ubuntu-cloud-keyring vim git ntp openssh-server curl
sudo echo "deb http://ubuntu-cloud.archive.canonical.com/ubuntu precise-updates/havana main" | sudo tee /etc/apt/sources.list.d/havana.list
sudo apt-get install python-software-properties -y
sudo apt-get update && apt-get upgrade -y

rm /etc/hosts
# sudo sed -i "s/^127.0.1.1.*/172.16.0.10 controller/g" /etc/hosts

echo "127.0.0.1 localhost
172.16.0.10 controller.local controller
172.16.0.11 compute1.local compute1
" > /etc/hosts

# Install NTP while we are here
echo "ntpdate controller
hwclock -w" | sudo tee /etc/cron.daily/ntpdate
chmod a+x /etc/cron.daily/ntpdate

sudo apt-get -y install mysql-server python-mysqldb rabbitmq-server

sudo sed -i "s/^bind\-address.*/bind-address = ${MYSQL_HOST}/g" /etc/mysql/my.cnf

# Skip Name Resolve
echo "[mysqld]
skip-name-resolve" > /etc/mysql/conf.d/skip-name-resolve.cnf

sudo restart mysql

#################### Keystone Install ####################

# Keystone install and configuration
sudo apt-get -y install keystone python-keystone python-keystoneclient

mysql -h localhost -uroot -p$MYSQL_ROOT_PASS -e "CREATE DATABASE keystone;"
mysql -h localhost -uroot -p$MYSQL_ROOT_PASS -e "GRANT ALL ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY '$MYSQL_PASS';"
mysql -h localhost -uroot -p$MYSQL_ROOT_PASS -e "GRANT ALL ON keystone.* TO 'keystone'@'%' IDENTIFIED BY '$MYSQL_PASS';"

# Configure the Keystone for our MySQL database
sudo sed -i 's#^connection.*#connection = mysql://keystone:openstack@127.0.0.1/keystone#' /etc/keystone/keystone.conf
sudo sed -i 's/^# admin_token.*/admin_token = ADMIN/' /etc/keystone/keystone.conf

# Restart the Keystone services
sudo stop keystone
sudo start keystone

sudo keystone-manage db_sync

sudo apt-get -y install python-keystoneclient

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

# admin role
keystone role-create --name admin

# Member role
keystone role-create --name Member

keystone tenant-create --name mastering --description "Default Mastering OpenStack Tenant" --enabled true

TENANT_ID=$(keystone tenant-list | awk '/\ mastering\ / {print $2}')

export PASSWORD=openstack
keystone user-create --name admin --tenant_id $TENANT_ID --pass $PASSWORD --email root@localhost --enabled true

TENANT_ID=$(keystone tenant-list | awk '/\ mastering\ / {print $2}')

ROLE_ID=$(keystone role-list | awk '/\ admin\ / {print $2}')

USER_ID=$(keystone user-list | awk '/\ admin\ / {print $2}')

keystone user-role-add --user $USER_ID --role $ROLE_ID --tenant_id $TENANT_ID

# Create the user
PASSWORD=openstack
keystone user-create --name demo --tenant_id $TENANT_ID --pass $PASSWORD --email demo@localhost --enabled true

TENANT_ID=$(keystone tenant-list | awk '/\ mastering\ / {print $2}')

ROLE_ID=$(keystone role-list | awk '/\ Member\ / {print $2}')

USER_ID=$(keystone user-list | awk '/\ demo\ / {print $2}')

# Assign the Member role to the demo user in mastering
keystone user-role-add --user $USER_ID --role $ROLE_ID --tenant_id $TENANT_ID

# OpenStack Compute Nova API Endpoint
keystone service-create --name nova --type compute --description 'OpenStack Compute Service'

# OpenStack Compute EC2 API Endpoint
keystone service-create --name ec2 --type ec2 --description 'EC2 Service'

# Glance Image Service Endpoint
keystone service-create --name glance --type image --description 'OpenStack Image Service'

# Keystone Identity Service Endpoint
keystone service-create --name keystone --type identity --description 'OpenStack Identity Service'

# Cinder Block Storage Endpoint
keystone service-create --name volume --type volume --description 'Volume Service'

# OpenStack Compute Nova API
NOVA_SERVICE_ID=$(keystone service-list | awk '/\ nova\ / {print $2}')

PUBLIC="http://$ENDPOINT:8774/v2/\$(tenant_id)s"
ADMIN=$PUBLIC
INTERNAL=$PUBLIC

keystone endpoint-create --region RegionOne --service_id $NOVA_SERVICE_ID --publicurl $PUBLIC --adminurl $ADMIN --internalurl $INTERNAL

# OpenStack Compute EC2 API
EC2_SERVICE_ID=$(keystone service-list | awk '/\ ec2\ / {print $2}')

PUBLIC="http://$ENDPOINT:8773/services/Cloud"
ADMIN="http://$ENDPOINT:8773/services/Admin"
INTERNAL=$PUBLIC

keystone endpoint-create --region RegionOne --service_id $EC2_SERVICE_ID --publicurl $PUBLIC --adminurl $ADMIN --internalurl $INTERNAL

# Glance Image Service
GLANCE_SERVICE_ID=$(keystone service-list | awk '/\ glance\ / {print $2}')

PUBLIC="http://$ENDPOINT:9292/v1"
ADMIN=$PUBLIC
INTERNAL=$PUBLIC

keystone endpoint-create --region RegionOne --service_id $GLANCE_SERVICE_ID --publicurl $PUBLIC --adminurl $ADMIN --internalurl $INTERNAL

# Keystone OpenStack Identity Service
KEYSTONE_SERVICE_ID=$(keystone service-list | awk '/\ keystone\ / {print $2}')

PUBLIC="http://$ENDPOINT:5000/v2.0"
ADMIN="http://$ENDPOINT:35357/v2.0"
INTERNAL=$PUBLIC

keystone endpoint-create --region RegionOne --service_id $KEYSTONE_SERVICE_ID --publicurl $PUBLIC --adminurl $ADMIN --internalurl $INTERNAL

# Cinder Block Storage Service
CINDER_SERVICE_ID=$(keystone service-list | awk '/\ volume\ / {print $2}')

PUBLIC="http://$ENDPOINT:8776/v1/%(tenant_id)s"
ADMIN=$PUBLIC
INTERNAL=$PUBLIC

keystone endpoint-create --region RegionOne --service_id $CINDER_SERVICE_ID --publicurl $PUBLIC --adminurl $ADMIN --internalurl $INTERNAL

# Service Tenant
keystone tenant-create --name service --description "Service Tenant" --enabled true

SERVICE_TENANT_ID=$(keystone tenant-list | awk '/\ service\ / {print $2}')

keystone user-create --name nova --pass nova --tenant_id $SERVICE_TENANT_ID --email nova@localhost --enabled true

keystone user-create --name glance --pass glance --tenant_id $SERVICE_TENANT_ID --email glance@localhost --enabled true

keystone user-create --name keystone --pass keystone --tenant_id $SERVICE_TENANT_ID --email keystone@localhost --enabled true

keystone user-create --name cinder --pass cinder --tenant_id $SERVICE_TENANT_ID --email cinder@localhost --enabled true

# Get the nova user id
NOVA_USER_ID=$(keystone user-list | awk '/\ nova\ / {print $2}')

# Get the admin role id
ADMIN_ROLE_ID=$(keystone role-list | awk '/\ admin\ / {print $2}')

# Assign the nova user the admin role in service tenant
keystone user-role-add --user $NOVA_USER_ID --role $ADMIN_ROLE_ID --tenant_id $SERVICE_TENANT_ID

# Get the glance user id
GLANCE_USER_ID=$(keystone user-list | awk '/\ glance\ / {print $2}')

# Assign the glance user the admin role in service tenant
keystone user-role-add --user $GLANCE_USER_ID --role $ADMIN_ROLE_ID --tenant_id $SERVICE_TENANT_ID

# Get the keystone user id
KEYSTONE_USER_ID=$(keystone user-list | awk '/\ keystone\ / {print $2}')

# Assign the keystone user the admin role in service tenant
keystone user-role-add --user $KEYSTONE_USER_ID --role $ADMIN_ROLE_ID --tenant_id $SERVICE_TENANT_ID

# Get the cinder user id
CINDER_USER_ID=$(keystone user-list | awk '/\ cinder \ / {print $2}')

# Assign the cinder user the admin role in service tenant
keystone user-role-add --user $CINDER_USER_ID --role $ADMIN_ROLE_ID --tenant_id $SERVICE_TENANT_ID

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


#################### Glance Install ####################

sudo apt-get install -y glance glance-api glance-registry python-glanceclient glance-common

mysql -h localhost -uroot -p$MYSQL_ROOT_PASS -e "CREATE DATABASE glance;"
mysql -h localhost -uroot -p$MYSQL_ROOT_PASS -e "GRANT ALL ON glance.* TO 'glance'@'localhost' IDENTIFIED BY '$MYSQL_PASS';"
mysql -h localhost -uroot -p$MYSQL_ROOT_PASS -e "GRANT ALL ON glance.* TO 'glance'@'%' IDENTIFIED BY '$MYSQL_PASS';"

sudo sed -i 's#^sql_connection.*#sql_connection = mysql://glance:openstack@127.0.0.1/glance#' /etc/glance/glance-registry.conf
sudo sed -i 's#^auth_host.*#auth_host = controller#' /etc/glance/glance-registry.conf
sudo sed -i 's#^admin_tenant_name.*#admin_tenant_name = service#' /etc/glance/glance-registry.conf
sudo sed -i 's#^admin_user.*#admin_user = glance#' /etc/glance/glance-registry.conf
sudo sed -i 's#^admin_password.*#admin_password = glance#' /etc/glance/glance-registry.conf

sudo sed -i 's#^sql_connection.*#sql_connection = mysql://glance:openstack@127.0.0.1/glance#' /etc/glance/glance-api.conf
sudo sed -i 's#^auth_host.*#auth_host = controller#' /etc/glance/glance-api.conf
sudo sed -i 's#^admin_tenant_name.*#admin_tenant_name = service#' /etc/glance/glance-api.conf
sudo sed -i 's#^admin_user.*#admin_user = glance#' /etc/glance/glance-api.conf
sudo sed -i 's#^admin_password.*#admin_password = glance#' /etc/glance/glance-api.conf

sudo sed -i '/^\[filter:authtoken\]/d' /etc/glance/glance-api-paste.ini
sudo sed -i '/^delay_auth_decision.*/d' /etc/glance/glance-api-paste.ini
sudo sed -i '/^paste.filter_factory = keystoneclient.middleware.auth_token.*/d' /etc/glance/glance-api-paste.ini

echo "auth_host = controller
admin_user = glance
admin_tenant_name = service
admin_password = glance
" | sudo tee -a /etc/glance/glance-registry-paste.ini

echo "
[filter:authtoken]
paste.filter_factory = keystoneclient.middleware.auth_token:filter_factory
auth_host = controller
admin_user = glance
admin_tenant_name = service
admin_password = glance
" | sudo tee -a /etc/glance/glance-api-paste.ini

service glance-api restart && service glance-registry restart

glance-manage db_sync

wget http://download.cirros-cloud.net/0.3.1/cirros-0.3.1-x86_64-disk.img
glance image-create --is-public true --disk-format qcow2 --container-format bare --name "Cirros 0.3.1" < cirros-0.3.1-x86_64-disk.img

#################### Nova Install ####################

apt-get install -y nova-novncproxy novnc nova-api nova-ajax-console-proxy nova-cert nova-conductor nova-consoleauth nova-doc nova-scheduler python-novaclient

mysql -h localhost -uroot -p$MYSQL_ROOT_PASS -e "CREATE DATABASE nova;"
mysql -h localhost -uroot -p$MYSQL_ROOT_PASS -e "GRANT ALL ON nova.* TO 'nova'@'localhost' IDENTIFIED BY '$MYSQL_PASS';"
mysql -h localhost -uroot -p$MYSQL_ROOT_PASS -e "GRANT ALL ON nova.* TO 'nova'@'%' IDENTIFIED BY '$MYSQL_PASS';"

sudo sed -i 's#^connection.*#connection = mysql://nova:openstack@127.0.0.1/nova#' /etc/nova/nova.conf
sudo sed -i 's#^auth_host.*#auth_host = controller#' /etc/nova/api-paste.ini
sudo sed -i 's#^admin_tenant_name.*#admin_tenant_name = service#' /etc/nova/api-paste.ini
sudo sed -i 's#^admin_user.*#admin_user = nova#' /etc/nova/api-paste.ini
sudo sed -i 's#^admin_password.*#admin_password = nova#' /etc/nova/api-paste.ini

nova-manage db sync

echo "
my_ip=172.16.0.10
vncserver_listen=172.16.0.10
vncserver_proxyclient_address=172.16.0.10
auth_strategy=keystone
rpc_backend = nova.rpc.impl_kombu
rabbit_host = controller" >> /etc/nova/nova.conf

service nova-api restart
service nova-cert restart
service nova-consoleauth restart
service nova-scheduler restart
service nova-conductor restart
service nova-novncproxy restart

#################### Cinder Install ####################


#################### Swift (proxy) Install ####################


#################### Horizon Install ####################

apt-get install -y memcached libapache2-mod-wsgi openstack-dashboard
apt-get remove -y --purge openstack-dashboard-ubuntu-theme

sudo sed -i "s/^\-l 127.0.0.1.*/-l 172.16.0.10/g" /etc/memcached.conf
sudo sed -i "s/^OPENSTACK_HOST.*/OPENSTACK_HOST = \"controller\"/g" /etc/openstack-dashboard/local_settings.py
sudo sed -i "s/127.0.0.1/172.16.0.10/g" /etc/openstack-dashboard/local_settings.py

mysql -h localhost -uroot -p$MYSQL_ROOT_PASS -e "CREATE DATABASE dash;"
mysql -h localhost -uroot -p$MYSQL_ROOT_PASS -e "GRANT ALL ON dash.* TO 'dash'@'localhost' IDENTIFIED BY '$MYSQL_PASS';"
mysql -h localhost -uroot -p$MYSQL_ROOT_PASS -e "GRANT ALL ON dash.* TO 'dash'@'%' IDENTIFIED BY '$MYSQL_PASS';"

# echo "
# SESSION_ENGINE = 'django.core.cache.backends.db.DatabaseCache'
# DATABASE = {
# 	'default': { 
#	# Database configuration here
#	'ENGINE': 'django.db.backends.mysql',
#	'NAME': 'dash',
#	'USER': 'dash',
#	'PASSWORD': 'openstack',
#	'HOST': 'localhost',
#	'default-character-set': 'utf8'
#	}
# }
# " >> /etc/openstack-dashboard/local_settings.py

. /etc/init.d/apache2 reload

#################### Heat Install ####################


#################### Telemetry Install ####################






