#!/usr/bin/env bash

# check_aws_access_keys.sh
# Stefan Wuensch, 2017-07-26
# 
# This takes all the "profile" entries from your ~/.aws/config file and outputs the
# IAM user name _and_ the AWS Account Name for each profile. In other words, you
# can give it a bunch of keys and it will tell you the username and acccount name
# if you don't know them! This is handy because sometimes you don't want to name
# the "profile" in the config file the same as the AWS Account name or username, 
# and over time you might forget which key is which! (I have done that!)
# 
# If there's an error getting the username or the account name (or both) the
# string "error" will replace the item that could not be found. If you get 
# "error@error" for output, it most likely means that Access Key has been 
# disabled / revoked.
# 


profiles=$( grep profile ~/.aws/config | sed -e 's/^.*profile //g' | cut -d\] -f1 | sort | uniq )

for n in $( echo $profiles ) ; do 
	username=$( aws iam get-user --query User.UserName --output=text --profile=$n 2>/dev/null ) || username="error"
	printf "$n : ${username}@"
	( aws iam list-account-aliases --profile $n --output text 2>/dev/null || echo eek error ) | awk '{print $2}'
done
