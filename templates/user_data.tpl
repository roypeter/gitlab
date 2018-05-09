#!/bin/bash

logfile="/var/log/aws_userdata.log"

# Mount EBS volumes
/sbin/mkfs -t ext4 /dev/xvdf >> $logfile
/bin/mkdir -p /var/opt/gitlab >> $logfile
/bin/echo "/dev/xvdf /var/opt/gitlab ext4 defaults,nofail 0 2" >> /etc/fstab
/bin/mount -av >> $logfile

# Install Gitlab
sudo apt-get update && sudo apt-get upgrade >> $logfile
sudo apt-get install -y curl openssh-server ca-certificates >> $logfile
curl -sS https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh | sudo bash >> $logfile
sudo apt-get install gitlab-ce >> $logfile
sudo gitlab-ctl reconfigure >> $logfile

echo "end of aws userdata" >> $logfile
