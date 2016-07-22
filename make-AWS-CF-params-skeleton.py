#!/usr/bin/env python2

###################################################################################################
# make-AWS-CF-params-skeleton.py
# 
# by Stefan Wuensch 2016-07-21
# 
# Input: AWS CloudFormation JSON template on STDIN 
#   Typically this means pipe the JSON to this script, such as 'cat' a local file
#   or "curl -s" an Amazon sample, or similar.
# 
# Output: JSON skeleton of CloudFormation Parameters file
# 
# Purpose: If you want to generate a CloudFormation Stack from
#   a CF template and separate JSON file for Parameters, this
#   will generate the framework of the required Parameters in
#   a JSON file which you can simply edit to fill in each ParameterValue.
# 
# 
# Additional Reading:
#   https://blogs.aws.amazon.com/application-management/post/Tx1A23GYVMVFKFD/Passing-Parameters-to-CloudFormation-Stacks-with-the-AWS-CLI-and-Powershell
# 
# 
# To Do: Add file input instead of just stdin
# 
###################################################################################################
# 
# Example:
#   This uses an online sample Amazon CF JSON Template. It is retrieved via curl and processed by this script.
#   Note how each "ParameterValue" contains "REPLACE THIS WITH:" and the "Description" from the template!! (Cool, eh?)
# 
# % curl -s https://s3.amazonaws.com/cloudformation-templates-us-east-1/LAMP_Single_Instance.template | make-AWS-CF-params-skeleton.py
# 
# [
#     {
#         "ParameterKey": "DBName", 
#         "ParameterValue": "REPLACE THIS WITH: MySQL database name"
#     }, 
#     {
#         "ParameterKey": "DBPassword", 
#         "ParameterValue": "REPLACE THIS WITH: Password for MySQL database access"
#     }, 
#     {
#         "ParameterKey": "DBRootPassword", 
#         "ParameterValue": "REPLACE THIS WITH: Root password for MySQL"
#     }, 
#     {
#         "ParameterKey": "DBUser", 
#         "ParameterValue": "REPLACE THIS WITH: Username for MySQL database access"
#     }, 
#     {
#         "ParameterKey": "InstanceType", 
#         "ParameterValue": "REPLACE THIS WITH: WebServer EC2 instance type"
#     }, 
#     {
#         "ParameterKey": "KeyName", 
#         "ParameterValue": "REPLACE THIS WITH: Name of an existing EC2 KeyPair to enable SSH access to the instance"
#     }, 
#     {
#         "ParameterKey": "SSHLocation", 
#         "ParameterValue": "REPLACE THIS WITH:  The IP address range that can be used to SSH to the EC2 instances"
#     }
# ] 
# 
# 
# If you were to save the output of the above example to a file named "example-params.json" (and put in 
#   valid ParameterValue entries) then you could:
# 
# % aws cloudformation create-stack --stack-name my-test-stack --template-body https://s3.amazonaws.com/cloudformation-templates-us-east-1/LAMP_Single_Instance.template --parameters file://example-params.json
# 
# 
# 
###################################################################################################

import sys, json, select

if not select.select( [ sys.stdin, ], [], [], 0.0 )[ 0 ]:
	print "Error: This program expects a CloudFormation JSON Template on STDIN. (For example, via a pipe.)"
	sys.exit( 1 )

inputJSON = json.loads( sys.stdin.read() )[ 'Parameters' ]
parameters = []
outputJSON = []

for parameter in inputJSON:
	parameters.append( parameter )
parameters.sort()

for parameter in parameters:
	thisParam = {}
	thisParam[ 'ParameterKey' ] = parameter
	thisParam[ 'ParameterValue' ] = "REPLACE THIS WITH: " + inputJSON[ parameter ][ 'Description' ]
	outputJSON.append( thisParam )

print "\n", json.dumps( outputJSON, sort_keys = True, indent = 4 ), "\n\n"
