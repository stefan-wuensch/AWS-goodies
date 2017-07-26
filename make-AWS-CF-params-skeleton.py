#!/usr/bin/env python2

###################################################################################################
# make-AWS-CF-params-skeleton.py
# 
# by Stefan Wuensch 2016-2017
# 
# Input: AWS CloudFormation JSON or YAML template on STDIN.
#   Typically this means pipe the JSON/YAML to this script, such as 'cat' a local file
#   or "curl -s" an Amazon sample, or "aws s3 cp" to '-', or similar.
# 
# Output: JSON skeleton of CloudFormation Parameters file.
#   AWS CloudFormation (still) does not support parameters files in YAML,
#   so this script will only output JSON - no matter what the input is.
# 
# Purpose: If you want to generate a CloudFormation Stack from a CF template and a separate
#   JSON file for Parameters, this will generate the framework of the required Parameters in
#   a JSON file which you can simply edit to fill in each ParameterValue. This makes it
#   really easy to stand up a CF stack, because the output from this script shows you
#   exactly what each Parameter Type must be, the allowed values, the default, etc.
# 
# 
# Additional Reading:
#   https://aws.amazon.com/blogs/devops/passing-parameters-to-cloudformation-stacks-with-the-aws-cli-and-powershell/
# 
# 
# To Do: Add file input/output instead of just stdin/stdout
# 
###################################################################################################
# 
# Example:
#   This uses an online sample Amazon CF JSON Template. It is retrieved via curl and processed by this script.
#   Note how each "ParameterValue" contains "REPLACE THIS WITH:" and the "Type", a list of any "AllowedValues", and
#   the "Description" from the template!! (Cool, eh?)
# 
# % curl -s https://s3.amazonaws.com/cloudformation-templates-us-east-1/LAMP_Single_Instance.template | make-AWS-CF-params-skeleton.py
# 
# [
#     {
#         "ParameterKey": "DBName", 
#         "ParameterValue": "REPLACE THIS WITH: String - MySQL database name"
#     }, 
#     {
#         "ParameterKey": "DBPassword", 
#         "ParameterValue": "REPLACE THIS WITH: String - Password for MySQL database access"
#     }, 
#     {
#         "ParameterKey": "DBRootPassword", 
#         "ParameterValue": "REPLACE THIS WITH: String - Root password for MySQL"
#     }, 
#     {
#         "ParameterKey": "DBUser", 
#         "ParameterValue": "REPLACE THIS WITH: String - Username for MySQL database access"
#     }, 
#     {
#         "ParameterKey": "InstanceType", 
#         "ParameterValue": "REPLACE THIS WITH: String - Allowed:[t1.micro, t2.nano, t2.micro, t2.small, t2.medium, t2.large, m1.small, m1.medium, m1.large, m1.xlarge, m2.xlarge, m2.2xlarge, m2.4xlarge, m3.medium, m3.large, m3.xlarge, m3.2xlarge, m4.large, m4.xlarge, m4.2xlarge, m4.4xlarge, m4.10xlarge, c1.medium, c1.xlarge, c3.large, c3.xlarge, c3.2xlarge, c3.4xlarge, c3.8xlarge, c4.large, c4.xlarge, c4.2xlarge, c4.4xlarge, c4.8xlarge, g2.2xlarge, g2.8xlarge, r3.large, r3.xlarge, r3.2xlarge, r3.4xlarge, r3.8xlarge, i2.xlarge, i2.2xlarge, i2.4xlarge, i2.8xlarge, d2.xlarge, d2.2xlarge, d2.4xlarge, d2.8xlarge, hi1.4xlarge, hs1.8xlarge, cr1.8xlarge, cc2.8xlarge, cg1.4xlarge] - WebServer EC2 instance type"
#     }, 
#     {
#         "ParameterKey": "KeyName", 
#         "ParameterValue": "REPLACE THIS WITH: AWS::EC2::KeyPair::KeyName - Name of an existing EC2 KeyPair to enable SSH access to the instance"
#     }, 
#     {
#         "ParameterKey": "SSHLocation", 
#         "ParameterValue": "REPLACE THIS WITH: String -  The IP address range that can be used to SSH to the EC2 instances"
#     }
# ] 
# 
# 
# If you were to save the output of the above example to a file named "example-params.json" (and put in
#   valid ParameterValue entries) then you could:
# 
# % aws cloudformation create-stack --stack-name my-test-stack --template-body https://s3.amazonaws.com/cloudformation-templates-us-east-1/LAMP_Single_Instance.template --parameters file://example-params.json
# 
# See how easy that is? With this script you can start up a complex CloudFormation stack easily,
# because each parameter to the stack is described in detail in the output of this script.
#
###################################################################################################

import sys, json, yaml, select

if not select.select( [ sys.stdin, ], [], [], 5 )[ 0 ]:		# Check for data, waiting 5 sec. max
	print "Error: This program expects a CloudFormation JSON or YAML Template on STDIN. (For example, via a pipe.)"
	sys.exit( 1 )

parameters = []
outputJSON = []
isJSON = False
isYAML = False


# Do we get data in STDIN?
try:
	input = sys.stdin.read()
except:
	print "Error: This program expects a CloudFormation JSON or YAML Template on STDIN. (For example, via a pipe.)"
	sys.exit( 1 )


# Is it JSON? If not, move on.
try:
	input = json.loads( input )
	isJSON = True
except Exception:
	# print "Input is not JSON."
	pass


# Is it YAML? NOTE: using "safe_load()" which is a best practice!
if not isJSON:
	try:
		input = yaml.safe_load( input )
		isYAML = True
	except Exception:
		# print "Input is not YAML."
		pass

if not isJSON and not isYAML:
	print "Error: This program expects a CloudFormation JSON or YAML Template on STDIN. (For example, via a pipe.)"
	sys.exit( 1 )

try:
	inputParameters = input[ 'Parameters' ]
except:
	print( 'Error: Did not find a "Parameters' + ( '":', ':"' )[ isYAML ] + ' section in the ' + ( 'JSON', 'YAML' )[ isYAML ] + ' input!' )
	print( 'Make sure you are sending a CloudFormation Template into this script. If you are, check your ' + ( 'JSON', 'YAML' )[ isYAML ] + ' syntax.' )
	print( "If your CF Template doesn't have Parameters, then you don't need to use this script!" )
	sys.exit( 1 )


for parameter in inputParameters:	# This is just so we can sort by parameter name
	parameters.append( parameter )
parameters.sort()

for parameter in parameters:
	thisParam = {}
	thisParam[ 'ParameterKey' ] = parameter
	thisParam[ 'ParameterValue' ] = "REPLACE THIS WITH: "	# We will be appending to this string with the additional stuff below

	if 'Type' in inputParameters[ parameter ]:
		thisParam[ 'ParameterValue' ] += str( inputParameters[ parameter ][ 'Type' ] ) + " - "

	if 'Default' in inputParameters[ parameter ]:
		thisParam[ 'ParameterValue' ] += 'Default:\'' + str( inputParameters[ parameter ][ 'Default' ] ) + "\' - "

	if 'AllowedValues' in inputParameters[ parameter ]:
		thisParam[ 'ParameterValue' ] += 'Allowed:[' + ', '.join( inputParameters[ parameter ][ 'AllowedValues' ] ) + '] - '

	if 'Description' in inputParameters[ parameter ]:
		thisParam[ 'ParameterValue' ] += str( inputParameters[ parameter ][ 'Description' ] )

	outputJSON.append( thisParam )

print json.dumps( outputJSON, sort_keys = True, indent = 4 )
