#!/bin/bash



# Veeam Enterprise Manager Server - API
SERVER_ADDRESS="192.168.1.1"
SERVER_PORT="9399"

API_URL="$SERVER_ADDRESS:$SERVER_PORT"

#TMP XML FILE
TMP_FILE="/tmp/tmp_resp.tmp"
JSON_FILE="/tmp/res.json.tmp"

# V.E.M. Credentials
USERNAME="yourusername"
PASSWORD="yourpassword"

BASE_URL="$API_URL/api/"

LOGIN_URL="$BASE_URL/sessionMngr/?v=latest"



###########################
#                         #
#         LOGIN           #
#                         #
###########################

# LOGIN V2 URL - POST REQUEST
curl --silent -d "" -X POST "$LOGIN_URL" -H "Content-Type: application/x-www-form-urlencoded"  -H "Authorization: Basic $(echo -n $USERNAME:$PASSWORD | base64)" -o $TMP_FILE

# EXTRACT SESSION ID
SESSION_ID=$(cat $TMP_FILE | grep -oPm1 "(?<=<SessionId>)[^<]+")






###########################
#                         #
#   Summary VMs Overview  #
#                         #
###########################

SUMMARY_OVERVIEW_URL="$BASE_URL/reports/summary/job_statistics"

curl --silent -d "" -X GET "$SUMMARY_OVERVIEW_URL" -H "Accept: application/json" -H "X-RestSvcSessionId: $(echo -n $SESSION_ID | base64)" -o $JSON_FILE

sum_ov_job_rj=$(jq -r ".RunningJobs" $JSON_FILE)
sum_ov_job_sj=$(jq -r ".ScheduledJobs" $JSON_FILE)
sum_ov_job_sbj=$(jq -r ".ScheduledBackupJobs" $JSON_FILE)
sum_ov_job_srj=$(jq -r ".ScheduledReplicaJobs" $JSON_FILE)
sum_ov_job_tjr=$(jq -r ".TotalJobRuns" $JSON_FILE)
sum_ov_job_str=$(jq -r ".SuccessfulJobRuns" $JSON_FILE)
sum_ov_job_wjr=$(jq -r ".WarningsJobRuns" $JSON_FILE)
sum_ov_job_fjr=$(jq -r ".FailedJobRuns" $JSON_FILE)

echo "veeamEntMgr_Job_Stat,tag=$SERVER_ADDRESS runningJobs=$sum_ov_job_rj"
echo "veeamEntMgr_Job_Stat,tag=$SERVER_ADDRESS scheduledJobs=$sum_ov_job_sj"
echo "veeamEntMgr_Job_Stat,tag=$SERVER_ADDRESS scheduledBackupJobs=$sum_ov_job_sbj"
echo "veeamEntMgr_Job_Stat,tag=$SERVER_ADDRESS scheduledReplicaJobs=$sum_ov_job_srj"
echo "veeamEntMgr_Job_Stat,tag=$SERVER_ADDRESS totalJobRuns=$sum_ov_job_tjr"
echo "veeamEntMgr_Job_Stat,tag=$SERVER_ADDRESS successfulJobRuns=$sum_ov_job_str"
echo "veeamEntMgr_Job_Stat,tag=$SERVER_ADDRESS warningJobRuns=$sum_ov_job_wjr"
echo "veeamEntMgr_Job_Stat,tag=$SERVER_ADDRESS failedJobRuns=$sum_ov_job_fjr"



###########################
#                         #
#  Summary Repo Overview  #
#                         #
###########################

SUMMARY_OVERVIEW_URL="$BASE_URL/repositories"

curl --silent -d "" -X GET "$SUMMARY_OVERVIEW_URL" -H "Accept: application/json" -H "X-RestSvcSessionId: $(echo -n $SESSION_ID | base64)" -o $JSON_FILE

repo_names=$(jq -r ".Refs" $JSON_FILE | jq -r ".[] .Href")

all_capacity=0
all_used=0
all_free=0

while read -r uid; do
        #echo "$uid"
        REPO_URL="$uid?format=Entity"
        curl --silent -d "" -X GET "$REPO_URL" -H "Accept: application/json" -H "X-RestSvcSessionId: $(echo -n $SESSION_ID | base64)" -o $JSON_FILE
        repo_capacity=$(jq -r ".Capacity" $JSON_FILE)
        repo_freespace=$(jq -r ".FreeSpace" $JSON_FILE)
        repo_used=`expr $repo_capacity - $repo_freespace`
        repo_name=$(jq -r ".Name" $JSON_FILE | sed -e 's/ /_/g')
        repo_kind=$(jq -r ".Kind" $JSON_FILE)
        echo "veeam_repo,hostname=$SERVER_ADDRESS,repoName=$repo_name capacity=$repo_capacity,free=$repo_freespace,used=$repo_used,kind=\"$repo_kind\""

	all_capacity=`expr $repo_capacity + $all_capacity`
	all_used=`expr $repo_used + $all_used`
	all_free=`expr $repo_freespace + $all_free`

done <<< "$repo_names"

echo "veeam_repo,hostname=$SERVER_ADDRESS all_capacity=$all_capacity,allfree=$all_free,allused=$all_used"





###########################
#                         #
#   Backup Session List   #
#                         #
###########################

SUMMARY_OVERVIEW_URL="$BASE_URL/backupTaskSessions"

curl --silent -d "" -X GET "$SUMMARY_OVERVIEW_URL" -H "Accept: application/json" -H "X-RestSvcSessionId: $(echo -n $SESSION_ID | base64)" -o $JSON_FILE

bkup_hrefs=$(jq -r ".Refs" $JSON_FILE | jq -r ".[] .Href")

while read -r uid; do

        REPO_URL="$uid?format=Entity"
        curl --silent -d "" -X GET "$REPO_URL" -H "Accept: application/json" -H "X-RestSvcSessionId: $(echo -n $SESSION_ID | base64)" -o $JSON_FILE
        bkup_vm_display_name=$(jq -r ".VmDisplayName" $JSON_FILE | sed -e 's/ /_/g')
        bkup_total_size=$(jq -r ".TotalSize" $JSON_FILE)
        bkup_state=$(jq -r ".State" $JSON_FILE | sed -e 's/ /_/g')
        bkup_result=$(jq -r ".Result" $JSON_FILE | sed -e 's/ /_/g')
        bkup_reason=$(jq -r ".Reason" $JSON_FILE)
	bkup_utc_time=$(jq -r ".CreationTimeUTC" $JSON_FILE)
	if [ -z "$bkup_reason" ]
	then
		bkup_reason="OK"
	fi
        echo "veeam_bkup_session,hostname=$SERVER_ADDRESS,vmName=$bkup_vm_display_name,res=$bkup_result total_size=$bkup_total_size,bkup_state=\"$bkup_state\",bkup_result=\"$bkup_result\",bkup_reason=\"$bkup_reason\",utc_time=\"$bkup_utc_time\""

done <<< "$bkup_hrefs"





rm -f $TMP_FILE
rm -f $JSON_FILE
