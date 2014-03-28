# -*- mode: ruby -*-
# vi: set ft=ruby :

nodes = {
    'controller'  => [1, 10],
    'compute1'  => [1, 11],
    # 'network'  => [1, 12],
}

Vagrant.configure("2") do |config|
    config.vm.box = "precise64"
    #config.vm.box_url = "http://files.vagrantup.com/precise64.box"
    config.vm.box_url = "C:\Users\ewright\Documents\GitHub\VirtualBox-MasteringOpenStack\precise64.box"

    #Default is 2200..something, but port 2200 is used by forescout NAC agent.
    config.vm.usable_port_range= 2800..2900 

    nodes.each do |prefix, (count, ip_start)|
        count.times do |i|
            hostname = "%s" % [prefix, (i+1)]

            config.vm.define "#{hostname}" do |box|
                box.vm.hostname = "#{hostname}"
                box.vm.network :private_network, ip: "172.16.0.#{ip_start+i}", :netmask => "255.255.0.0"
                box.vm.network :private_network, ip: "10.0.0.#{ip_start+i}", :netmask => "255.255.0.0" 

                box.vm.provision :shell, :path => "#{prefix}.sh"

                # If using Fusion
                box.vm.provider :vmware_fusion do |v|
                    v.vmx["memsize"] = 1024
        	    if prefix == "compute"
	              	v.vmx["memsize"] = 2048
	            end
                end

                # Otherwise using VirtualBox
                box.vm.provider :virtualbox do |vbox|
	            # Defaults
                    vbox.customize ["modifyvm", :id, "--memory", 2048]
                    vbox.customize ["modifyvm", :id, "--cpus", 1]
		    if prefix == "compute"
                    	vbox.customize ["modifyvm", :id, "--memory", 3072]
                        vbox.customize ["modifyvm", :id, "--cpus", 2]
		    elsif prefix == "controller"
		        vbox.customize ["modifyvm", :id, "--memory", 2048]
			file_to_disk = './cinder.vdi'
			vbox.customize ['createhd', '--filename',file_to_disk, '--size', 50*1024]
			vbox.customize ['storageattach', :id, '--storagectl', 'SATA Controller', '--port', 1, '--device', 0, '--type', 'hdd', '--medium', file_to_disk]
		    elsif prefix == "network"
		        vbox.customize ["modifyvm", :id, "--memory", 2048]
		    end
                end
            end
        end
    end
end
