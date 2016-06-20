Stuff to make your life easier when working with AWS.
=============


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


