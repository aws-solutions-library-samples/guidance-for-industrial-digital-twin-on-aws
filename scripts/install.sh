# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

### Download repos
git clone https://github.com/aws-solutions-library-samples/breweries-sitewise-simulator.git

### Install Packages
pip3 install boto3 --no-input
sudo yum install -y docker
sudo systemctl enable docker.service
sudo systemctl start docker.service

### Setup Cron job for refreshing EC2 IAM credentials to pass to the Grafana Container
sudo chkconfig crond on
sudo service crond start
sh update_credentials.sh
(crontab -l ; echo "*/30 * * * * sudo sh /guidance-for-industrial-digital-twin-on-aws/scripts/update_credentials.sh") | crontab -

### Setup Env Variables
export AWS_DEFAULT_REGION=`wget -q -O - http://169.254.169.254/latest/meta-data/placement/region`
export ROLE_NAME="EC2InstanceRole"
export ACCOUNT_ID=`aws sts get-caller-identity --query "Account" --output text`
export INSTANCE_ID=`wget -q -O - http://169.254.169.254/latest/meta-data/instance-id`
export DOMAIN_NAME=`wget -q -O - http://169.254.169.254/latest/meta-data/public-hostname`
export CURRENT_USER_ARN=arn:aws:sts::$ACCOUNT_ID:assumed-role/$ROLE_NAME/$INSTANCE_ID
echo $CURRENT_USER_ARN

export BUCKET=twinmaker-workspace-brewery-$ACCOUNT_ID-$AWS_DEFAULT_REGION

## Setup Brewery Scenes and Grafana Dashboards
echo "Migrating Brewery Demo Files..."
python3 migrate_files.py $BUCKET
echo "Brewery Demo Files Migrated"

## Install Grafana Dashboard Role
echo "Installing Grafana Dashboard IAM Role..."
aws cloudformation create-stack --stack-name GrafanaDashboardIAM --template-body file://../cf/GrafanaDashboardRole.json --parameters ParameterKey=UserARN,ParameterValue=$CURRENT_USER_ARN ParameterKey=ResourcePrefix1,ParameterValue=GrafanaBreweryDashboardRole ParameterKey=ResourcePrefix2,ParameterValue=BreweryManufacturing ParameterKey=S3BucketPrefix,ParameterValue=brewery --capabilities CAPABILITY_NAMED_IAM
aws cloudformation wait stack-create-complete --stack-name "GrafanaDashboardIAM"
echo "IAM Role Created"

## Update TwinMaker Datasource 
echo "Configuring Grafana datasource for TwinMaker..."
export GrafanaRole=`aws cloudformation describe-stacks --stack-name GrafanaDashboardIAM --query "Stacks[0].Outputs[?OutputKey=='GrafanaRoleArn'].OutputValue" --output text`
sed -i "s|AWSREGION|$AWS_DEFAULT_REGION|g" ../provisioning/datasources/twinmaker_datasource.yaml
sed -i "s|IAMROLE|$GrafanaRole|g" ../provisioning/datasources/twinmaker_datasource.yaml

## Install Grafana
echo "Installing Grafana Dashboard..."
sh setup_grafana_docker.sh
echo "Dashboard is ready on http://$DOMAIN_NAME"
