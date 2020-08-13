#!/bin/bash -xe

# install necessary dependencies 
sudo yum -y install git python3 python-pip3 jq awslogs
sudo pip3 install --upgrade boto3 statsd

# install collectd optionally (requires epel installed)
# yum install collectd

# get region from instance metadata
REGION=`curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq .region -r`
aws configure set region $REGION

# download the source files from github
git clone https://github.com/asksac/AWSGridWithSQS.git
cd AWSGridWithSQS

# hack to avoid 'open /usr/share/collectd/types.db: no such file or directory' error
sudo mkdir -p /usr/share/collectd/
sudo touch /usr/share/collectd/types.db

# download and install cloudwatch agent
wget "https://s3.${REGION}.amazonaws.com/amazoncloudwatch-agent-${REGION}/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm" -P /tmp
sudo rpm -U /tmp/amazon-cloudwatch-agent.rpm
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:./config/cwagent-conf.json -s

sudo mkdir /var/log/AWSGridWithSQS
sudo chown ec2-user:ec2-user /var/log/AWSGridWithSQS