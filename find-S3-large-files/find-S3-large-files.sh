#!/usr/bin/env bash

# find-S3-large-files.sh
# 
# by Stefan Wuensch, September 2016
# 
# version 2016-09-21
# 
# Usage: find-S3-large-files.sh [ name-of-S3-bucket ... ]
# 
# This script will scan one or more S3 buckets and show you:
# 
# 1. A summary of the total number of objects (files) in the bucket
# 2. The total number of bytes in use in the entire bucket
# 3. The timestamp of the oldest file in the bucket (regardless of size)
# 4. The timestamp of the newest file in the bucket (regardless of size)
# 5. The top __8__ files larger than __50__ MB. (Each constraint value can be customized by changing a variable in the script.)
# 
# 
# __Notes__
# 
# - if a bucket does not have any files larger than 50 MB (or whatever value is in the variable `MIN_MB`) then only the summary table is shown.
# 
# - the divider line with equals characters "`====`" separates output for each bucket
# 
# - file timestamps are UTC
# 
# - in this document and in the script, "file" and "object" are used interchangeably - although in reality a "file" is what's on a filesystem and once it's in S3 it's no longer a "file" it's an "object". :-)  https://aws.amazon.com/s3/faqs/
# 
# - if your AWS account requires MFA to use the CLI tools, you can use these functions to set up the required STS: https://bitbucket.org/huitcloudservices/aws-cli-sts/src
# 
# 
# References:
# http://docs.aws.amazon.com/cli/latest/userguide/controlling-output.html
# http://jmespath.org/specification.html
# 
# 
# 
# AWS CLI Examples from development:
# for bucket in $( aws s3api list-buckets --output text --query 'Buckets[*].Name' ) ; do echo "==================== ${bucket} ========================"; aws s3api list-objects-v2 --bucket ${bucket} --query 'Contents[?Size > `104857600`].[Size,Key]' --output text | perl -MMath::Round -pe 's/(\d+)/nearest(.01,$1\/1024\/1024)/eg' | sort -n | tail -20 ; done
# aws s3api list-objects-v2 --query "[sum(Contents[].Size), length(Contents[])]" --output json --bucket adts-deploy-dev-bucket
# aws s3api list-objects-v2 --query "{ TotalSize:sum(Contents[].Size), TotalObjects:length(Contents[]) }" --output json --bucket adts-deploy-dev-bucket
# aws s3api list-objects-v2 --bucket "${bucket}" --query "[ sort( Contents[].LastModified ) ]"
# aws s3api list-objects-v2 --bucket "${bucket}" --query "{ Dates:sort( Contents[].LastModified ) }"
# aws s3api list-objects-v2 --bucket "${bucket}" --query "{ Oldest:sort( Contents[].LastModified )[0], Newest:sort( Contents[].LastModified )[-1] }" --output table



######################################################################
# Customizable Variables
MIN_MB=50		# Show files that are larger than this
NUMBER_OF_FILES=8	# Only show this number of large files
######################################################################


MIN_BYTES=$(( MIN_MB * 1024 * 1024 ))

# Capture signals and force an exit because the AWS CLI seems to have its own signal handling that gets in the way
trap "exit 127" EXIT HUP INT QUIT TERM

# If we get args, assume they are bucket names to be examined.
# If not, get a list of all bucket names.
if [[ $# -ne 0 ]] ; then
	buckets="${*}"
else
	buckets=$( aws s3api list-buckets --output text --query 'Buckets[*].Name' )
fi

echo -e "\nShowing top ${NUMBER_OF_FILES} largest files (S3 objects) greater than ${MIN_MB} MB (if any) in the following buckets:\n${buckets}"

for bucket in $( echo ${buckets} ) ; do

	# Make a nice header line. Note how the 'head' makes it a uniform length,
	# no matter how long is the bucket name. (The 'echo' at the end is because
	# 'head -c' also drops the newline. The 'echo' puts it back.)
	echo -e "\n\n========= Bucket: ${bucket} =======================================================================================================" |
		head -c 115 ; echo

	# See if it's there, and see if we can view it.
	# http://docs.aws.amazon.com/cli/latest/reference/s3api/head-bucket.html
	aws s3api head-bucket --bucket "${bucket}" >/dev/null 2>&1
	if [[ $? -ne 0 ]] ; then
		echo "Error: Bucket \"${bucket}\" either does not exist, or you do not have rights to access it."
		continue
	fi

	# See if the bucket is empty. If it is, skip to the next. This avoids needing to
	# handle errors from the sum() function if there's nothing to be totaled.
	if [[ -z "$( aws s3 ls s3://${bucket} )" ]] ; then
		echo "(Empty bucket)"
		continue
	fi

	# Run the summaries
	# (This query was a challenge to get working, but not as much as the next one!)
	# http://docs.aws.amazon.com/cli/latest/reference/s3api/list-objects-v2.html
	aws s3api list-objects-v2 --query "{ Total_Bucket_Size_Bytes:sum( Contents[].Size ),
					Total_Objects_in_Bucket:length( Contents[] ),
					Oldest_of_All_Files:sort( Contents[].LastModified )[0],
					Newest_of_All_Files:sort( Contents[].LastModified )[-1] }" --bucket "${bucket}" --output table

	echo	# Just for making the first table stand out from the next table.

	# Do the large files
	# Can't use '--max-items "${NUMBER_OF_FILES}"' as one would expect, because that limits the
	# _input_ to the Size conditional - not the number of files shown in output! Ugh.
	aws s3api list-objects-v2 --bucket "${bucket}" --output table \
		--query "reverse( sort_by( Contents, &Size )[?Size > \`${MIN_BYTES}\`].{Size_in_MB:Size,File_Name:Key,File_Last_Modified:LastModified})" |
			perl -MMath::Round -pe 's/(\|  )(\d+)( +\|)/$1 . nearest(.01,$2\/1024\/1024) . " MB  |"/eg' |
			head -$(( NUMBER_OF_FILES + 5 ))	# The addition of 5 is to account for the table headers.


	# This is an alternate way of showing the sizes, but it's not as "pretty" as the
	# table view above. However, I'm keeping it in here (commented out) in case
	# someone finds a simple list of MB and file name useful. Also it's handy to confirm the
	# complex query in the largest-objects output above.
	aws s3api list-objects-v2 --bucket "${bucket}" --query "Contents[?Size > \`${MIN_BYTES}\`].[Size,Key]" --output text |
		perl -MMath::Round -pe 's/(^\d+)/nearest(.001,$1\/1024\/1024) . " MB"/eg' |
		sort -n |
		tail -${NUMBER_OF_FILES}

	echo	# Just for making the output stand out from what comes next.
done


# Remove the trap to exit as specified. (Not required, just best practice.)
trap "" EXIT HUP INT QUIT TERM
