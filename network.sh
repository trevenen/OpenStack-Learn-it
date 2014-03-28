sudo apt-get update
sudo apt-get install -y vim git
git clone https://github.com/discoposse/MasteringOpenStack.git /home/vagrant/MasteringOpenStack
source /home/vagrant/MasteringOpenStack/openrc
echo "source /home/vagrant/MasteringOpenStack/openrc" >> ~/.bashrc
