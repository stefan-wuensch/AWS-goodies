Stuff to make your life easier when working with AWS.




MFA-STS_functions
===========

AWS_STS_functions.bash
----------------------
A collection of bash functions which set up AWS session tokens for CLI use with an MFA.

AWS_STS_functions.zsh
---------------------
A similar collection of functions (but for zsh) which include additional functionality, such as one-line invocation. 




Check_admins_for_MFA
===========

check_aws_admins_mfa.zsh
----------------------
A script which looks at all the user accounts in an administrators' group and checks to see if they are also in 
a group which enforces the use of MFA.

For details, see:
https://blogs.aws.amazon.com/security/post/Tx2SJJYE082KBUK/How-to-Delegate-Management-of-Multi-Factor-Authentication-to-AWS-IAM-Users
https://s3.amazonaws.com/awsiammedia/public/sample/DelegateManagementofMFA/DelegateManagementofMFA_policydocument_060115.txt

