Stuff to make your life easier when working with AWS.
==================

See also https://bitbucket.org/srw812/aws-goodies-in-bitbucket/src


Scripts
==================


## check_aws_access_keys.sh


### Usage:

`check_aws_access_keys.sh [ name-of-AWS-config-profile ]`

### Requires:
	- AWS CLI
	- AWS IAM User Access Key(s) in either or both:
		~/.aws/config
		~/.aws/credentials

### Optional:
	- User IAM Policy allowed actions iam:GetUser and iam:ListAccountAliases

### Example Output:
	deploy : deploy-account@mycompany-production
	my-dev-profile : john_doe@johns-AWS-dev-account
	not-working-keys : error@error
	prod : john_doe@mycompany-production

### Description

This takes "profile" entries from your AWS config & credentials files and outputs the IAM user name _and_ the AWS Account Name for each profile. In other words, you can give it a bunch of keys and it will tell you the username and account name if you don't know them! This is handy because sometimes you don't want to name the "profile" in the config file the same as the AWS Account name or username, and over time you might forget which key is which! (I have done that!)

If no argument is given, this will grab all "profile" entries from your `~/.aws/config` and/or `~/.aws/credentials` files. An optional argument can be given if you want to check only that one profile. (Only one arg will be used. Any others will be ignored.)

If there's an error getting the username or the account name (or both) the string `error` will replace the item that could not be found. If you get `error@error` for output, it most likely means that Access Key has been disabled / revoked.

Note: if the IAM User account for a certain Access Key / profile does not have the IAM permission `iam:ListAccountAliases`, an attempt will still be made to grab the AWS Account numeric ID. If the output for a particular profile looks like `john_doe@123456789012` then you know the Access Key is working, but the `iam:ListAccountAliases` permission is not given to that IAM User account.

### See also:

http://docs.aws.amazon.com/cli/latest/userguide/cli-multiple-profiles.html

http://docs.aws.amazon.com/cli/latest/userguide/cli-config-files.html

http://docs.aws.amazon.com/IAM/latest/APIReference/API_GetUser.html

http://docs.aws.amazon.com/IAM/latest/APIReference/API_ListAccountAliases.html





Check_admins_for_MFA
----------------------
A script which looks at all the user accounts in an administrators' group and checks to see if they are also in 
a group which enforces the use of MFA.

For details, see:
https://blogs.aws.amazon.com/security/post/Tx2SJJYE082KBUK/How-to-Delegate-Management-of-Multi-Factor-Authentication-to-AWS-IAM-Users
https://s3.amazonaws.com/awsiammedia/public/sample/DelegateManagementofMFA/DelegateManagementofMFA_policydocument_060115.txt




MFA-STS_functions
----------------------
A collection of shell code / functions which set up AWS session tokens for CLI use with an MFA.




Bitbucket-S3-diff.zsh
-------------
Script which compares a local repo check-out to a remote S3 bucket location. Displays file differences
and gives command examples to sync / upload.

See detailed notes in script comments.

**New feature 2016-08-10**: Added command option arg '--sync-metadata' which will copy from local up to
S3 if (and **only if**) a file's contents are exactly the same in both locations and only the 
metadata differs. In other words: if the timestamp is the only thing that makes "aws s3 sync"
think the file is different - and the contents are actually 100% the same - then this new option will
copy to S3 (even though it's the same thing there already) simply so that the metadata will be the same
and additional runs of this script will not show the file.




Generic_Safe_Temp_Dir_Function.sh
---------------------------------
This code can be dropped into any bash script for setting up a temporary
directory. The directory will be created with a unique name, and will
be automatically removed (along with all the contents) when the script
completes. Note that the "EXIT" being trapped will catch any exit of the 
script that includes this code - not just user-generated signals like ^C.




## final-build-with-EFS.sh

A bash script for auto-configuring and mounting EFS (NFS) export during instance build process.




## find-CF-stack-for-AWS-resource.sh


### Description
This script is a really simple wrapper around an AWS query. If you don't know
which CloudFormation Stack created a particular resource in your AWS account,
it can be almost impossible to find the stack. 

This is particularly the case for 
CloudWatch Alarms, because Alarms do not have the ability to be tagged. (As of 2016-08-31)

Other AWS resources can be tagged with details like the Stack Name, but 
in case they are not tagged this script can be used.


### Usage examples

__Usage__: `find-CF-stack-for-AWS-resource.sh "the name of an AWS resource"`

__Requires__: The name ("Physical Resource ID") of an AWS resource

__Output__: The name of a CloudFormation Stack (if found) which created / manages that resource,
or an AWS CLI error message which includes "Stack for {resource name} does not exist"

#### Example of the not-found language
```
$ find-CF-stack-for-AWS-resource.sh "not-a-real-resource just an example"
An error occurred (ValidationError) when calling the DescribeStackResources operation: Stack for not-a-real-resource just an example does not exist
```

#### Example of searching for the stack that created an EC2 instance
```
$ find-CF-stack-for-AWS-resource.sh i-d01e7d4d
museDbDeploy-dev-asglc-cf
```

#### Example of searching for the stack that created a CloudWatch Alarm
```
$ find-CF-stack-for-AWS-resource.sh "fastcat.faoapps.fas.harvard.edu prod elb-request-count-high-cw-alarm"
fastcat-prod-elb-cw-cf
```

#### Example of searching for a stack that does not exist
In this case there is __no__ stack which created this Alarm! __This particular Alarm is stand-alone.__ It was 
not created by CloudFormation. What's different here from the first not-found example above? In this case
we know the Alarm resource does exist - therefore this tells us there's no CF Stack. You need to be absolutely
sure you are giving a valid arg to the command, and quoting it as necessary.
```
$ find-CF-stack-for-AWS-resource.sh "qlik.huit.harvard.edu qlikprdm RDS FreeStorageSpace"
An error occurred (ValidationError) when calling the DescribeStackResources operation: Stack for qlik.huit.harvard.edu qlikprdm RDS FreeStorageSpace does not exist
```






find-S3-large-files.sh
-----------------------------
This script will scan one or more S3 buckets and show you:

1. A summary of the total number of objects (files) in the bucket
2. The total number of bytes in use in the entire bucket
3. The timestamp of the oldest file in the bucket (regardless of size)
4. The timestamp of the newest file in the bucket (regardless of size)
5. The top __8__ files larger than __50__ MB. (Each constraint value can be customized by changing a variable in the script.)



make-AWS-CF-params-skeleton.py
-------------------------------
This script takes a JSON AWS CloudFormation Template on STDIN (from a pipe or similar) 
and generates a JSON parameters skeleton from the Parameters of the template.
This can be used to create a CloudFormation Parameters file for input to the 
AWS CLI. See the "aws cloudformation create-stack" example in the script.

The only required arguments to create a stack from the CLI (which is why this 
is so cool) are:

* --stack-name
* --template-body
* --parameters

_Using the AWS web Console to enter stack parameters is poor form! Don't do it!_
