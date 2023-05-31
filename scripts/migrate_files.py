# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

import json
import os
import logging
import boto3
from botocore.exceptions import ClientError
import csv
import sys

SESSION = boto3.Session()
TM_CLIENT = SESSION.client('iottwinmaker')

modelsDir = "../3dmodels/"
scenesDir = "../scenes/"
grafanaDir = "../dashboards/"
alertsDir = "../provisioning/alerting/"
originalIDs = "../mapping/original_property_ids.csv"
workspaceid = "BreweryManufacturing"

bucket = "twinmaker-workspace-brewery"
if(len(sys.argv) > 1):
    bucket = str(sys.argv[1]).lower()

def upload_file(file_name, bucket, object_name=None):
    """Upload a file to an S3 bucket

    :param file_name: File to upload
    :param bucket: Bucket to upload to
    :param object_name: S3 object name. If not specified then file_name is used
    :return: True if file was uploaded, else False
    """

    # If S3 object_name was not specified, use file_name
    if object_name is None:
        object_name = os.path.basename(file_name)

    # Upload the file
    s3_client = boto3.client('s3')
    try:
        response = s3_client.upload_file(file_name, bucket, object_name)
    except ClientError as e:
        logging.error(e)
        return False
    return True
    
def copyResources(directory, bucket):
    """Copies all 3D models to the Workspace S3 Bucket

    :param directory: local directory to scan
    :param bucket: Bucket to upload to
    :return: True if file was uploaded, else False
    """
    try:
        for filename in os.listdir(directory):
            upload_file(modelsDir+filename, bucket)
    except Exception as e:
        logging.error(e)
        return False
    return True

def replaceTextInFile(filename, search_text, replace_text):
    try:
        with open(filename, 'r') as file:
      
            # Reading the content of the file
            # using the read() function and storing
            # them in a new variable
            data = file.read()
          
            # Searching and replacing the text
            # using the replace() function
            data = data.replace(search_text, replace_text)
          
        # Opening our text file in write only
        # mode to write the replaced content
        with open(filename, 'w') as file:
          
            # Writing the replaced data in our
            # text file
            file.write(data)
    except Exception as e:
        logging.error(e)
        return False
    
    return True

def replaceIDsInScenesAndDashboards(scenedirectory, grafanadirectory, alertsdirectory, workspaceid):
    """Replace IDs for properties in scene files and Grafana Dashboards

    :param scenedirectory: local directory to scan for scenes
    :param scenedirectory: local directory to scan for grafana dashboards
    :param workspaceid: Workspace ID
    :return: True if successful, else False
    """
    newIDs = getNewPropertyIDsFromTwinMaker()
    oldIds = getOldPropertyIDs(originalIDs)
    
    # Replace SiteWise IDs
    for key, record in oldIds.items():
        # Replace in scene files
        for filename in os.listdir(scenedirectory):
            try:
                replaceTextInFile(scenedirectory+filename, record[0], newIDs[key][0])
                replaceTextInFile(scenedirectory+filename, record[1], newIDs[key][1])
            except Exception as e:
                logging.error(e)
                
        # Replace in Grafana Dashboards
        for filename in os.listdir(grafanadirectory):
            try:
                replaceTextInFile(grafanadirectory+filename, record[0], newIDs[key][0])
                replaceTextInFile(grafanadirectory+filename, record[1], newIDs[key][1])
            except Exception as e:
                logging.error(e)

        # Replace in Grafana Alerts
        for filename in os.listdir(alertsdirectory):
            try:
                replaceTextInFile(alertsdirectory+filename, record[0], newIDs[key][0])
                replaceTextInFile(alertsdirectory+filename, record[1], newIDs[key][1])
            except Exception as e:
                logging.error(e)
    
    # Replace Bucket and Create Scenes in TwinMaker
    for filename in os.listdir(scenedirectory):
        replaceTextInFile(scenedirectory+filename, "{bucket}", bucket)
        
        try:
            response = TM_CLIENT.create_scene(
                workspaceId=workspaceid,
                sceneId=os.path.splitext(filename)[0],
                contentLocation="s3://{}/{}".format(bucket,filename),
                description= os.path.splitext(filename)[0]
            )
        except Exception as e:
            logging.error(e)
            
        # Replace Scene file in s3
        upload_file(scenedirectory+filename, bucket)


def getOldPropertyIDs(filename):
    """Opening mapping file with the original set of entity and property IDs

    :param filename: filename of CSV mapping file to process
    :return: a matrix of original mapping of IDs
    """

    matrix = {}
    with open(filename, 'r') as csvfile:
        datareader = csv.reader(csvfile)
        next(datareader,None)
        for row in datareader:
            entityName = row[0]
            entityId = row[1]
            propertyDisplayName = row[2]
            propertyName = row[3]
            matrix[(entityName, propertyDisplayName)] = [entityId, propertyName]

    return matrix            

def getNewPropertyIDsFromTwinMaker():
    """Query TwinMaker Workspace to find new set of entity and property IDs

    :return: a matrix of new mapping of IDs
    """
    query = """select entity.entityName, entity.entityId, p.definition.displayName, p.propertyName 
               from EntityGraph match (entity), entity.components c, c.properties p 
               where c.componentName = 'sitewiseBase'"""
      
    matrix={}
    
    response = TM_CLIENT.execute_query(
        workspaceId=workspaceid,
        queryStatement=query,
        maxResults=100
    )
    
    # Get all rows
    results = response["rows"]
    while "nextToken" in response:
        response = TM_CLIENT.execute_query(
            workspaceId=workspaceid,
            queryStatement=query,
            maxResults=100,
            nextToken= response["nextToken"]
        ) 
        results.extend(response["rows"])

    # Place data into a matrix
    for row in results:
        entityName = row['rowData'][0]
        entityId = row['rowData'][1]
        propertyDisplayName = row['rowData'][2]
        propertyName = row['rowData'][3]
        matrix[(entityName, propertyDisplayName)] = [entityId, propertyName]
        
    
    return matrix
    
copyResources(modelsDir, bucket)
replaceIDsInScenesAndDashboards(scenesDir, grafanaDir, alertsDir, workspaceid)
