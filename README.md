Stuff to make your life easier when working with AWS.
==================


See also https://bitbucket.org/srw812/aws-goodies-in-bitbucket/src


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



Generic_Safe_Temp_Dir_Function.sh
---------------------------------
This code can be dropped into any bash script for setting up a temporary
directory. The directory will be created with a unique name, and will
be automatically removed (along with all the contents) when the script
completes. Note that the "EXIT" being trapped will catch any exit of the 
script that includes this code - not just user-generated signals like ^C.



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
