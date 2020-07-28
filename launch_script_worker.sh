#!/bin/bash -xe

# enables logs from user data script to be viewable via console
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# debugging only
pwd

# install necessary dependencies 
yum -y install git python3 python-pip3 jq awslogs
pip3 install --upgrade boto3 statsd

# install collectd optionally (requires epel installed)
# yum install collectd

# get region from instance metadata
REGION=`curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq .region -r`

# download the source files from github
git clone https://github.com/asksac/AWSGridWithSQS.git
cd AWSGridWithSQS

# hack to avoid 'open /usr/share/collectd/types.db: no such file or directory' error
mkdir -p /usr/share/collectd/
touch /usr/share/collectd/types.db

# download and install cloudwatch agent
wget "https://s3.${REGION}.amazonaws.com/amazoncloudwatch-agent-${REGION}/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm" -P /tmp
rpm -U /tmp/amazon-cloudwatch-agent.rpm
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:./config/cwagent-conf.json -s

mkdir /var/log/AWSGridWithSQS
chown ec2-user:ec2-user /var/log/AWSGridWithSQS

sudo -u ec2-user aws configure set region $REGION
sudo -u ec2-user python3 src/worker/main.py &

