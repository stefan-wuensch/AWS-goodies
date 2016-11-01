[TOC]

# find-S3-large-files.sh

This script will scan one or more S3 buckets and show you:

1. A summary of the total number of objects (files) in the bucket
2. The total number of bytes in use in the entire bucket
3. The timestamp of the oldest file in the bucket (regardless of size)
4. The timestamp of the newest file in the bucket (regardless of size)
5. The top __8__ files larger than __50__ MB. (Each constraint value can be customized by changing a variable in the script.)


__Notes__

- if a bucket does not have any files larger than 50 MB (or whatever value is in the variable `MIN_MB`) then only the summary table is shown.

- the divider line with equals characters "`====`" separates output for each bucket

- file timestamps are UTC

- in this document and in the script, "file" and "object" are used interchangeably - although in reality a "file" is what's on a filesystem and once it's in S3 it's no longer a "file" it's an "object". :-)  https://aws.amazon.com/s3/faqs/

- if your AWS account requires MFA to use the CLI tools, you can use these functions to set up the required STS: https://bitbucket.org/huitcloudservices/aws-cli-sts/src



## Examples



### Bucket names given on the command-line
```
$ find-S3-large-files.sh ace-assets-dev ace-assets-prod ace-deployments-dev ace-deployments-prod ace-deployments-qa adts-deploy-dev-bucket caads-ace-software-bucket cdntest000al

Showing top 8 largest files (S3 objects) greater than 50 MB (if any) in the following buckets:
ace-assets-dev ace-assets-prod ace-deployments-dev ace-deployments-prod ace-deployments-qa adts-deploy-dev-bucket caads-ace-software-bucket cdntest000al


========= Bucket: ace-assets-dev ================================================================================
----------------------------------------------------------------------------------------------------------------
|                                                 ListObjectsV2                                                |
+---------------------------+----------------------------+--------------------------+--------------------------+
|    Newest_of_All_Files    |    Oldest_of_All_Files     | Total_Bucket_Size_Bytes  | Total_Objects_in_Bucket  |
+---------------------------+----------------------------+--------------------------+--------------------------+
|  2016-09-08T15:59:32.000Z |  2015-03-17T23:35:00.000Z  |  676318665               |  23322                   |
+---------------------------+----------------------------+--------------------------+--------------------------+




========= Bucket: ace-assets-prod ===============================================================================
----------------------------------------------------------------------------------------------------------------
|                                                 ListObjectsV2                                                |
+---------------------------+----------------------------+--------------------------+--------------------------+
|    Newest_of_All_Files    |    Oldest_of_All_Files     | Total_Bucket_Size_Bytes  | Total_Objects_in_Bucket  |
+---------------------------+----------------------------+--------------------------+--------------------------+
|  2016-09-21T18:27:13.000Z |  2015-09-10T18:56:39.000Z  |  2089970011              |  31481                   |
+---------------------------+----------------------------+--------------------------+--------------------------+




========= Bucket: ace-deployments-dev ===========================================================================
----------------------------------------------------------------------------------------------------------------
|                                                 ListObjectsV2                                                |
+---------------------------+----------------------------+--------------------------+--------------------------+
|    Newest_of_All_Files    |    Oldest_of_All_Files     | Total_Bucket_Size_Bytes  | Total_Objects_in_Bucket  |
+---------------------------+----------------------------+--------------------------+--------------------------+
|  2015-04-08T11:36:20.000Z |  2015-02-06T15:58:21.000Z  |  9838811836              |  69                      |
+---------------------------+----------------------------+--------------------------+--------------------------+

-------------------------------------------------------------------------------------------------
|                                         ListObjectsV2                                         |
+---------------------------+-----------------------------------------------------+-------------+
|    File_Last_Modified     |                      File_Name                      | Size_in_MB  |
+---------------------------+-----------------------------------------------------+-------------+
|  2015-04-08T11:36:20.000Z |  ACE-nightly-deploy-5355724136051859817.zip         |  212.48 MB  |
|  2015-04-07T22:00:42.000Z |  ACE-nightly-deploy-8288999201868634777.zip         |  212.48 MB  |
|  2015-04-06T21:09:11.000Z |  ACE-nightly-deploy-7186184321812911681.zip         |  212.21 MB  |
|  2015-04-06T19:59:37.000Z |  ACE-nightly-deploy-4880947071847240022.zip         |  212.2 MB  |
|  2015-04-07T17:51:35.000Z |  ACE-nightly-deploy-2045212357205558861.zip         |  211.96 MB  |
|  2015-04-07T17:38:35.000Z |  ACE-nightly-deploy-9166136533479061059.zip         |  211.96 MB  |
|  2015-04-07T16:44:09.000Z |  ACE-nightly-deploy-9170616315694083094.zip         |  211.96 MB  |
|  2015-04-06T23:01:12.000Z |  ACE-nightly-deploy-3431600120027911323.zip         |  211.96 MB  |



========= Bucket: ace-deployments-prod ==========================================================================
(Empty bucket)


========= Bucket: ace-deployments-qa ============================================================================
(Empty bucket)


========= Bucket: adts-deploy-dev-bucket ========================================================================
----------------------------------------------------------------------------------------------------------------
|                                                 ListObjectsV2                                                |
+---------------------------+----------------------------+--------------------------+--------------------------+
|    Newest_of_All_Files    |    Oldest_of_All_Files     | Total_Bucket_Size_Bytes  | Total_Objects_in_Bucket  |
+---------------------------+----------------------------+--------------------------+--------------------------+
|  2016-09-21T20:15:04.000Z |  2015-09-08T20:35:48.000Z  |  3838410811              |  9167                    |
+---------------------------+----------------------------+--------------------------+--------------------------+

----------------------------------------------------------------------------------------------------------------
|                                                 ListObjectsV2                                                |
+---------------------------+--------------------------------------------------------------------+-------------+
|    File_Last_Modified     |                             File_Name                              | Size_in_MB  |
+---------------------------+--------------------------------------------------------------------+-------------+
|  2016-09-15T18:00:51.000Z |  fainfo/app/deploy/codedeploy.tar.gz                               |  819.14 MB  |
|  2016-09-15T17:59:33.000Z |  fainfo/app/deploy/tomcat/fainfo.war                               |  409.83 MB  |
|  2016-09-20T21:11:03.000Z |  XReg/deploy/codedeploy.tar.gz                                     |  140.16 MB  |
|  2016-09-14T17:22:04.000Z |  faads/deploy/codedeploy.tar.gz                                    |  134.2 MB  |
|  2016-09-15T14:22:41.000Z |  tfalloc/app/deploy/codedeploy.tar.gz                              |  121.79 MB  |
|  2016-09-07T19:48:56.000Z |  nora/app/deploy/codedeploy.tar.gz                                 |  116.07 MB  |
|  2016-09-21T17:55:10.000Z |  muse/deploy/codedeploy.tar.gz                                     |  101.65 MB  |
|  2016-09-13T16:38:12.000Z |  tsp/app/deploy/codedeploy.tar.gz                                  |  98.82 MB  |



========= Bucket: caads-ace-software-bucket =====================================================================
----------------------------------------------------------------------------------------------------------------
|                                                 ListObjectsV2                                                |
+---------------------------+----------------------------+--------------------------+--------------------------+
|    Newest_of_All_Files    |    Oldest_of_All_Files     | Total_Bucket_Size_Bytes  | Total_Objects_in_Bucket  |
+---------------------------+----------------------------+--------------------------+--------------------------+
|  2015-04-07T21:18:50.000Z |  2014-12-18T16:19:37.000Z  |  10467834625             |  54                      |
+---------------------------+----------------------------+--------------------------+--------------------------+

------------------------------------------------------------------------------------------------------
|                                            ListObjectsV2                                           |
+---------------------------+----------------------------------------------------------+-------------+
|    File_Last_Modified     |                        File_Name                         | Size_in_MB  |
+---------------------------+----------------------------------------------------------+-------------+
|  2015-02-11T16:26:36.000Z |  sqlplus_copied_from_aceorcl/12.1.0.1ACEDEV.tar          |  7895.7 MB  |
|  2015-01-21T18:00:26.000Z |  win64_11gR2_client.zip                                  |  587.18 MB  |
|  2015-04-02T13:18:47.000Z |  solr.collections.tgz                                    |  206.95 MB  |
|  2015-02-24T02:43:53.000Z |  solr.collections-v2.tgz                                 |  200.29 MB  |
|  2015-01-21T20:53:12.000Z |  solr-4.7.2.tgz                                          |  144.93 MB  |
|  2015-03-20T13:26:43.000Z |  solr.collections.tgz--current.copy.3.20.15              |  139.17 MB  |
|  2014-12-18T16:19:52.000Z |  java_ee_sdk-7u1.zip                                     |  127.57 MB  |
|  2015-02-23T16:23:30.000Z |  solr-5.0.0.tgz                                          |  121.89 MB  |



========= Bucket: cdntest000al ==================================================================================
----------------------------------------------------------------------------------------------------------------
|                                                 ListObjectsV2                                                |
+---------------------------+----------------------------+--------------------------+--------------------------+
|    Newest_of_All_Files    |    Oldest_of_All_Files     | Total_Bucket_Size_Bytes  | Total_Objects_in_Bucket  |
+---------------------------+----------------------------+--------------------------+--------------------------+
|  2015-05-14T18:11:13.000Z |  2015-05-14T13:48:55.000Z  |  136625491               |  3                       |
+---------------------------+----------------------------+--------------------------+--------------------------+

---------------------------------------------------------------------
|                           ListObjectsV2                           |
+---------------------------+-------------------------+-------------+
|    File_Last_Modified     |        File_Name        | Size_in_MB  |
+---------------------------+-------------------------+-------------+
|  2015-05-14T18:11:13.000Z |  Boot2Docker-1.5.0.pkg  |  129.8 MB  |
+---------------------------+-------------------------+-------------+
```




### No command-line argument

This example is truncated. It's just to show how all the buckets will be discovered and listed.


```
$ find-S3-large-files.sh

Showing top 8 largest files (S3 objects) greater than 50 MB (if any) in the following buckets:
ace-assets-dev	ace-assets-prod	ace-assets-qa	ace-assets-test	ace-deployments-dev	ace-deployments-prod	ace-deployments-qa	ace-deployments-test	ace-devops-scripts	admints-gmas-cachepoc-dev-bucket	adts-deploy-dev-bucket	adts-deploy-dev-bucket-logs	adts-deploy-sand-bucket	adts-deploy-sand-log-bucket	adts-deploy-test-bucket	adts-deploy-test-bucket-logs	adts-deploy-uat-bucket	adts-fastcat-dev-bucket	adts-fastcat-dev-bucket-logs	adts-fastcat-test-bucket	adts-fastcat-test-bucket-logs	adts-gmas-app-dev-bucket	ats-devops-deploy	ats-devops-dev	ats-devops-logs	ats-qlikview-deploy	ats-winstack-remediation	caads-ace-software-bucket	caads-ansible-artifacts	caads-cloudtrail-logs	caads-devops	cdntest000al	cf-templates-bisccc1wtieb-us-east-1	cloudformation-parking-lot	config-bucket-001980101248	crossreg-elb-logs	elasticbeanstalk-us-east-1-001980101248	jeff-qlik-bucket	qlikview-data	qlikview-data-backup	qlikview-keys	winstack-remediation-linux	xreg-api-elb-troubleshoot


========= Bucket: ace-assets-dev ================================================================================
----------------------------------------------------------------------------------------------------------------
|                                                 ListObjectsV2                                                |
+---------------------------+----------------------------+--------------------------+--------------------------+
|    Newest_of_All_Files    |    Oldest_of_All_Files     | Total_Bucket_Size_Bytes  | Total_Objects_in_Bucket  |
+---------------------------+----------------------------+--------------------------+--------------------------+
|  2016-09-08T15:59:32.000Z |  2015-03-17T23:35:00.000Z  |  676318665               |  23322                   |
+---------------------------+----------------------------+--------------------------+--------------------------+






```
