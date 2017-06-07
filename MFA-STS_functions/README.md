MFA-STS_functions
===========

AWS_STS_functions.sh
----------------------
A collection of bash functions which set up AWS session tokens for CLI use with an MFA.

AWS_STS_functions.zsh
---------------------
A similar collection of functions (but for zsh) which include additional functionality, such as one-line invocation.


aws_creds
----------------------
A zsh script which makes it super-easy and super-quick to use MFA for your AWS account.

It supports initializing an STS session (similar to the two above scripts) but *also*
allows for getting the AWS account password and MFA one-time-password value into the
Mac OS copy/paste buffer for easy entry into the AWS Console web UI!
