#!/bin/bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

SCRIPT_DIR=${HOME}

CONTAINER_NAME=brewery-grafana

# Prepare directories for grafana
mkdir -p ${SCRIPT_DIR}/local_grafana_data/plugins
mkdir -p ${SCRIPT_DIR}/local_grafana_data/dashboards
mkdir -p ${SCRIPT_DIR}/local_grafana_data/alerting
mkdir -p ${SCRIPT_DIR}/local_grafana_data/provisioning/datasources
mkdir -p ${SCRIPT_DIR}/local_grafana_data/provisioning/dashboards
mkdir -p ${SCRIPT_DIR}/local_grafana_data/provisioning/alerting
chmod 777 ${SCRIPT_DIR}/local_grafana_data
chmod 777 ${SCRIPT_DIR}/local_grafana_data/plugins
chmod 777 ${SCRIPT_DIR}/local_grafana_data/dashboards
chmod 777 ${SCRIPT_DIR}/local_grafana_data/provisioning
chmod 777 ${SCRIPT_DIR}/local_grafana_data/alerting
chmod 777 ${SCRIPT_DIR}/local_grafana_data/provisioning/datasources
chmod 777 ${SCRIPT_DIR}/local_grafana_data/provisioning/dashboards
chmod 777 ${SCRIPT_DIR}/local_grafana_data/provisioning/alerting
sudo usermod -a -G docker ec2-user

# Overwrite the grafana plugin with the latest code from the zip
rm -rf ${SCRIPT_DIR}/local_grafana_data/plugins/grafana-iot-twinmaker-app

# Copy alerts, datasource, and dashboards to local grafana directory for provisioning
cp ../provisioning/datasources/*.* ${SCRIPT_DIR}/local_grafana_data/provisioning/datasources/
cp ../provisioning/dashboards/*.* ${SCRIPT_DIR}/local_grafana_data/provisioning/dashboards/
cp ../provisioning/alerting/*.* ${SCRIPT_DIR}/local_grafana_data/provisioning/alerting/
cp ../dashboards/*.* ${SCRIPT_DIR}/local_grafana_data/dashboards/

# Remove a container if it exists. Using a volume to persist data so the new container
# will have the same configuration.
docker rm --force ${CONTAINER_NAME} &> /dev/null

docker run -d --restart unless-stopped \
  -p 80:3000 \
  --name=${CONTAINER_NAME} \
  -v ${SCRIPT_DIR}/local_grafana_data:/var/lib/grafana \
  -v ${SCRIPT_DIR}/local_grafana_data/provisioning:/etc/grafana/provisioning \
  -v ${SCRIPT_DIR}/local_grafana_data/dashboards:/var/lib/grafana/dashboards \
  -v ${SCRIPT_DIR}/local_grafana_data/alerting:/var/lib/grafana/alerting \
  -v ${SCRIPT_DIR}/.aws:/usr/share/grafana/.aws \
  -e "GF_INSTALL_PLUGINS=grafana-iot-twinmaker-app" \
  -e "GF_SECURITY_ALLOW_EMBEDDING=true" \
  -e "GF_PANELS_DISABLE_SANITIZE_HTML=true" \
  grafana/grafana
