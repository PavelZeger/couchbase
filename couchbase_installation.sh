#############################
# SSH session configuration #
#############################

vim /etc/ssh/sshd_config

	ClientAliveInterval 100m
	ClientAliveCountMax 0

systemctl restart sshd

##################################
# Disabling firewall and SELinux #
##################################

systemctl stop firewalld
systemctl disable firewalld
vim /etc/sysconfig/selinux

	SELINUX=disabled

reboot

################
# OS preparing #
################

yum install -y epel-release
yum install -y htop wget vim mlocate ncdu

# NTP installation and configuring
yum install -y ntp
systemctl enable ntpd
systemctl start ntpd
timdedatectl status
ntpstat
ntpq -p

# Disabling Transparent Huge Pages (THP)
cat /sys/kernel/mm/transparent_hugepage/enabled
cat /sys/kernel/mm/transparent_hugepage/defrag

# Create init script

		#!/bin/bash
		### BEGIN INIT INFO
		# Provides:          disable-thp
		# Required-Start:    $local_fs
		# Required-Stop:
		# X-Start-Before:    couchbase-server
		# Default-Start:     2 3 4 5
		# Default-Stop:      0 1 6
		# Short-Description: Disable THP
		# Description:       disables Transparent Huge Pages (THP) on boot
		### END INIT INFO

		case $1 in
		start)
		  if [ -d /sys/kernel/mm/transparent_hugepage ]; then
		    echo 'never' > /sys/kernel/mm/transparent_hugepage/enabled
		    echo 'never' > /sys/kernel/mm/transparent_hugepage/defrag
		  elif [ -d /sys/kernel/mm/redhat_transparent_hugepage ]; then
		    echo 'never' > /sys/kernel/mm/redhat_transparent_hugepage/enabled
		    echo 'never' > /sys/kernel/mm/redhat_transparent_hugepage/defrag
		  else
		    return 0
		  fi
		;;
		esac

# Create a file with the above code:
vim /etc/init.d/disable-thp
chmod 755 /etc/init.d/disable-thp
service disable-thp start
echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo never > /sys/kernel/mm/transparent_hugepage/defrag{{}}
# Make sure the Init script starts at boot
chkconfig disable-thp on
systemctl enable disable-thp
cat /sys/kernel/mm/transparent_hugepage/enabled
cat /sys/kernel/mm/transparent_hugepage/defrag

# Alternative way to disable THP
grep AnonHugePages /proc/meminfo 
egrep 'trans|thp' /proc/vmstat
grep -e AnonHugePages  /proc/*/smaps | awk  '{ if($2>4) print $0} ' |  awk -F "/"  '{print $0; system("ps -fp " $3)} '
vim /etc/default/grub

  GRUB_TIMEOUT=5
  GRUB_DEFAULT=saved
  GRUB_DISABLE_SUBMENU=true
  GRUB_TERMINAL_OUTPUT="console"
  GRUB_CMDLINE_LINUX="nomodeset crashkernel=auto rd.lvm.lv=vg_os/lv_root rd.lvm.lv=vg_os/lv_swap rhgb quiet transparent_hugepage=never numa=off elevator=noop"
  GRUB_DISABLE_RECOVERY="true"

grub2-mkconfig -o /boot/grub2/grub.cfg
shutdown -r now
cat /proc/cmdline

  BOOT_IMAGE=/vmlinuz-3.10.0-514.10.2.el7.x86_64 root=/dev/mapper/vg_os-lv_root ro nomodeset crashkernel=auto

grep -i HugePages_Total /proc/meminfo 
cat /proc/sys/vm/nr_hugepages 
sysctl vm.nr_hugepages

# Update swappiness
cat /proc/sys/vm/swappiness
sh -c 'echo 0 > /proc/sys/vm/swappiness'
cp -p /etc/sysctl.conf /etc/sysctl.conf.`date +%Y%m%d-%H:%M`
sh -c 'echo "" >> /etc/sysctl.conf'
sh -c 'echo "#Set swappiness to 0 to avoid swapping" >> /etc/sysctl.conf'
sh -c 'echo "vm.swappiness = 0" >> /etc/sysctl.conf'

# Setting hard limits
cd /etc/security/limits.d
vim 91-couchbase.conf

		couchbase soft nproc 4096
		couchbase hard nproc 16384

###################################
# Java installation for analytics #
###################################

cd /opt/
wget --no-cookies --no-check-certificate --header \
"Cookie: gpw_e24=http%3A%2F%2Fwww.oracle.com%2F; oraclelicense=accept-securebackup-cookie" \
"https://download.oracle.com/otn-pub/java/jdk/8u201-b09/42970487e3af4f5aa5bca3f542482c60/jre-8u201-linux-x64.tar.gz"
tar xzf jre-8u201-linux-x64.tar.gz
cd /opt/jre1.8.0_201/
alternatives --install /usr/bin/java java /opt/jre1.8.0_201/bin/java 2
alternatives --config java
alternatives --install /usr/bin/jar jar /opt/jre1.8.0_201/bin/jar 2
alternatives --install /usr/bin/javac javac /opt/jre1.8.0_201/bin/javac 2
alternatives --set jar /opt/jre1.8.0_201/bin/jar
alternatives --set javac /opt/jre1.8.0_201/bin/javac
java -version
export JAVA_HOME=/opt/jre1.8.0_201
export JRE_HOME=/opt/jre1.8.0_201/jre
export PATH=$PATH:/opt/jre1.8.0_201/bin:/opt/jre1.8.0_201/jre/bin

##########################
# Couchbase installation #
##########################

yum list | grep pkgconfig
yum install -y pkgconfig

# Please ensure that you are running OpenSSL v1.0.1g or higher!!!
rpm -q -a | grep "openssl"

curl -O http://packages.couchbase.com/releases/couchbase-release/couchbase-release-1.0-5-x86_64.rpm
rpm -i couchbase-release-1.0-5-x86_64.rpm
yum update -y
yum install -y couchbase-server-community

systemctl enable couchbase-server
systemctl status couchbase-server

##################################

couchbase-cli node-init 
    --cluster url 						# Hostname of first node in cluster 
    --username user 					# User executing the command
    --password password 				# Password of user executing the command
    --node-init-data-path path 			# Location where database files will be stored
    --node-init-index-path path 		# Location where indexes will be stored
    --node-init-analytics-path path 	# Location where Analytics data will be stored
    --node-init-hostname hostname 		# Hostname that the cluster will use for this node
    --node-init-java-home path 			# Location of alternative JRE for the Analytics service

# After initializing the first node, you can use the cluster-init command to initialize the cluster. 
# The following CLI syntax allows the establishing of administrative credentials and port number. 
# It adds all services, sets separate RAM quotas for Data, Index, Search, Eventing, and Analytics services, and sets the Index Storage Setting, the default being to support memory-optimized global indexes.

couchbase-cli cluster-init
    --cluster url 								# Hostname of first node in cluster
    --cluster-username user 					# New cluster administrator username
    --cluster-password password 				# New cluster administrator password
    --cluster-port port 						# New cluster REST/http port
    --cluster-ramsize ramsizemb 				# Per-node data service RAM quota in MB
    --cluster-name ramsizemb 					# Per-node data service RAM quota in MB
    --cluster-index-ramsize ramsizemb 			# Per-node index service RAM quota in MB
    --cluster-fts-ramsize ramsizemb 			# Per-node search service RAM quota in MB
    --cluster-eventing-ramsize ramsizemb 		# Per-node eventing service RAM quota in MB
    --cluster-analytics-ramsize ramsizemb 		# Per-node analytics service RAM quota in MB
    --index-storage-setting settings 			# Index storage type: default or memopt
    --services data,index,query,fts,analytics 	# Services to run on first node in cluster

##########################
# Couchbase verification #
##########################

# Web verification
http://[server A IP address]:8091
# Console verification
/opt/couchbase/bin/cbworkloadgen -n localhost:8091 
/opt/couchbase/bin/cbworkloadgen -n 172.20.100.113:8091
/opt/couchbase/bin/cbworkloadgen -n localhost:8091 -v -t 1 -b default -u USERNAME -p 
/opt/couchbase/bin/cbworkloadgen --node=localhost:8091 --verbose --threads=1 --bucket=default --username=USERNAME --password=PASSWORD  
/opt/couchbase/bin/cbq stats
/opt/couchbase/bin/cbq list
/opt/couchbase/bin/cbq timecheck

/opt/couchbase/bin/ -h
/opt/couchbase/bin/ --help
/opt/couchbase/bin/
/opt/couchbase/bin/cbq --engine http://localhost:8091
/opt/couchbase/bin/cbq -e http://localhost:8091
cbq> \CONNECT http://localhost:8091;
cbq> \HELP command-name;
cbq> \HELP;
cbq> \EXIT;
cbq> \QUIT;

# https://docs.couchbase.com/server/6.0/tools/cbq-shell.html

systemctl daemon-reexec
systemctl daemon-reload
systemctl stop couchbase-server
systemctl start couchbase-server

# Uninstall Couchbase
rpm -e couchbase-server
rm -rf /opt/couchbase/

# Do not start XDCR until every node in each cluster says synchronized!!!
