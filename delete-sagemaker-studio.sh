#!/bin/sh

REGION=us-east-1

SLEEP_DELAY=15

DOMAIN_INFO=$(aws --region $REGION sagemaker list-domains)

DOMAINS=$(echo $DOMAIN_INFO | jq -r .Domains[].DomainId)

OLD_IFS=$IFS
IFS=$'\n'
for DOMAIN in "$DOMAINS"; do
    DELETED=0
    FOUND=999
    while [ $DELETED -ne $FOUND ]; do
        DELETED=0
        FOUND=0
        DOMAIN_APPS=$(aws --region $REGION sagemaker list-apps --domain-id-equals $DOMAIN | jq -rc .Apps[])
        for DOMAIN_APP in ${DOMAIN_APPS}; do
            let FOUND+=1
            echo $DOMAIN_APP
            
            APP_NAME=$(echo $DOMAIN_APP | jq -r ".AppName")
            APP_TYPE=$(echo $DOMAIN_APP | jq -r ".AppType")
            USER_PROFILE_NAME=$(echo $DOMAIN_APP | jq -r ".UserProfileName")
            STATUS=$(echo $DOMAIN_APP | jq -rc ".Status")
            if [ "$STATUS" == "InService" ]; then
                echo "status is InService: ${DOMAIN_APP}"
                aws --region $REGION sagemaker delete-app \
                    --domain-id $DOMAIN \
                    --app-name $APP_NAME \
                    --app-type $APP_TYPE \
                    --user-profile-name $USER_PROFILE_NAME
            elif [ "$STATUS" == "Pending" ]; then
                echo "status is pending: ${DOMAIN_APP}"
            elif [ "$STATUS" == "Deleting" ]; then
                echo "status is deleting: ${DOMAIN_APP}"
            elif [ "$STATUS" == "Deleted" ]; then
                echo "status is deleted: ${DOMAIN_APP}"
                let DELETED+=1
            else
                echo "Unknown status \"$STATUS\": ${DOMAIN_APP}"
            fi
        done
        if [ $FOUND -ne $DELETED ]; then
            sleep $SLEEP_DELAY
            echo "sleep done"
        fi
    done

    DELETED=0
    FOUND=999
    while [ $DELETED -ne $FOUND ]; do 
        DELETED=0
        FOUND=0

        USER_PROFILES=$(aws --region $REGION sagemaker list-user-profiles --domain-id-equals $DOMAIN | jq -rc .UserProfiles[])
        for PROFILE in $USER_PROFILES; do
            let FOUND+=1
            USER_PROFILE_NAME=$(echo $PROFILE | jq -rc .UserProfileName)
            STATUS=$(echo $PROFILE | jq -rc ".Status")
            if [ "$STATUS" == "InService" ]; then
                echo "status is InService: ${PROFILE}"
                aws --region $REGION sagemaker delete-user-profile \
                    --domain-id $DOMAIN \
                    --user-profile-name $USER_PROFILE_NAME
            elif [ "$STATUS" == "Pending" ]; then
                echo "status is pending: ${PROFILE}"
            elif [ "$STATUS" == "Deleting" ]; then
                echo "status is deleting: ${PROFILE}"
            elif [ "$STATUS" == "Deleted" ]; then
                echo "status is deleted: ${PROFILE}"
                let DELETED+=1
            else
                echo "Unknown status \"$STATUS\": ${PROFILE}"
            fi
        done
        if [ $FOUND -ne $DELETED ]; then
            sleep $SLEEP_DELAY
            echo "sleep done"
        fi
  done

    aws --region $REGION sagemaker delete-domain \
        --domain-id $DOMAIN \
        --retention-policy HomeEfsFileSystem=Retain
done


IFS=$OLD_IFS
