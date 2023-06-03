#!/bin/bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

# EC2 metadata endpoint
metadata_url="http://169.254.169.254/latest/meta-data/"

# Retrieve the temporary credentials from EC2 metadata
role_name=$(curl -s "${metadata_url}iam/security-credentials/")
if [ $? -eq 0 ]; then
    role_name=$(echo "$role_name" | tr -d '\n')
    #echo "IAM role name: $role_name"

    credentials=$(curl -s "${metadata_url}iam/security-credentials/${role_name}")
    if [ $? -eq 0 ]; then
        access_key=$(echo "$credentials" | grep -oP '"AccessKeyId" : "\K[^"]+')
        secret_key=$(echo "$credentials" | grep -oP '"SecretAccessKey" : "\K[^"]+')
        session_token=$(echo "$credentials" | grep -oP '"Token" : "\K[^"]+')

        # Create the credentials file for the root user
        mkdir -p /local_grafana_data/.aws
        echo -e "[default]\naws_access_key_id = ${access_key}\naws_secret_access_key = ${secret_key}\naws_session_token = ${session_token}" > /local_grafana_data/.aws/credentials

        # Retrieve the region from EC2 metadata
        region=$(curl -s "${metadata_url}placement/region")
        #echo "Region: $region"

        # Create the config file for the root user
        echo -e "[default]\nregion = ${region}\noutput = json" > /local_grafana_data/.aws/config

        echo "Credentials and config files created successfully for the root user."
    else
        echo "Failed to retrieve temporary credentials."
    fi
else
    echo "Failed to retrieve IAM role information."
fi
