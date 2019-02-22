#!/usr/bin/env bash

# Docu: https://docs.gitlab.com/ce/api/merge_requests.html
# Modify by: Juan Manuel Torres (Tedezed)

# Extract the host where the server is running, and add the URL to the APIs
[[ $HOST =~ ^https?://[^/]+ ]] && HOST="${BASH_REMATCH[0]}/api/v4/projects/"

# Look which is the default branch
TARGET_BRANCH=`curl --silent "${HOST}${CI_PROJECT_ID}" --header "PRIVATE-TOKEN:${PRIVATE_TOKEN}" | python -c "import sys, json; print(json.load(sys.stdin)['default_branch'])"`;

#PREFIX="WIP: "
#    \"title\": \"${PREFIX}${CI_COMMIT_REF_NAME}-${RANDOM}$(date +"%N")\",

# The description of our new MR, we want to remove the branch after the MR has
# been closed
BODY_CREATE="{
    \"id\": ${CI_PROJECT_ID},
    \"source_branch\": \"${CI_COMMIT_REF_NAME}\",
    \"target_branch\": \"${TARGET_BRANCH}\",
    \"remove_source_branch\": true,
    \"title\": \"${PREFIX}${CI_COMMIT_REF_NAME}\",
    \"assignee_id\":\"${GITLAB_USER_ID}\",
    \"merge_when_pipeline_succeeds\": true
}";

# Require a list of all the merge request and take a look if there is already
# one with the same source branch
LISTMR=`curl --silent "${HOST}${CI_PROJECT_ID}/merge_requests?state=opened" --header "PRIVATE-TOKEN:${PRIVATE_TOKEN}"`;
COUNTBRANCHES=`echo ${LISTMR} | grep -o "\"source_branch\":\"${CI_COMMIT_REF_NAME}\"" | wc -l`;

# No MR found, let's create a new one
if [ ${COUNTBRANCHES} -eq "0" ]; then
    # Create new pull request to default branch
    MERGE_IID=`curl -X POST "${HOST}${CI_PROJECT_ID}/merge_requests" \
        --header "PRIVATE-TOKEN:${PRIVATE_TOKEN}" \
        --header "Content-Type: application/json" \
        --data "${BODY_CREATE}" | python -c "import sys, json; print(json.load(sys.stdin)['iid'])"`;

    echo "Opened a new merge request: ${PREFIX}${CI_COMMIT_REF_NAME} and assigned to you";

    # Auto merge previus pull request
    curl -X PUT "${HOST}${CI_PROJECT_ID}/merge_requests/${MERGE_IID}/merge" \
        --header "PRIVATE-TOKEN:${PRIVATE_TOKEN}" \
        --header "Content-Type: application/json" \
        --data "{\"id\": \"${CI_PROJECT_ID}\",\"merge_request_iid\": \"${MERGE_IID}\",\"merge_when_pipeline_succeeds\": true}";
    exit;
fi

echo "No new merge request opened";


