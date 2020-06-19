#!/bin/bash
yum -y install git python3 python-pip3 jq
pip3 install --upgrade boto3
REGION=`curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq .region -r`
sudo -u ec2-user aws configure set region $REGION
