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
            
            APP_NAME=$(echo $DOMAIN_APP | jq -r ".AppName")
            APP_TYPE=$(echo $DOMAIN_APP | jq -r ".AppType")
            USER_PROFILE_NAME=$(echo $DOMAIN_APP | jq -r ".UserProfileName")
            STATUS=$(echo $DOMAIN_APP | jq -rc ".Status")

            STATUS_MSG="Domain=${DOMAIN} AppName=${APP_NAME} AppType=${APP_TYPE}"
            echo "status is ${STATUS}: ${STATUS_MSG}"
            if [ "$STATUS" == "InService" ]; then
                echo "Deleting App: ${STATUS_MSG}"
                aws --region $REGION sagemaker delete-app \
                    --domain-id $DOMAIN \
                    --app-name $APP_NAME \
                    --app-type $APP_TYPE \
                    --user-profile-name $USER_PROFILE_NAME
            elif [ "$STATUS" == "Pending" ]; then
                :
            elif [ "$STATUS" == "Deleting" ]; then
                :
            elif [ "$STATUS" == "Deleted" ]; then
                let DELETED+=1
            else
                echo "Unknown status \"$STATUS\": ${DOMAIN_APP}"
            fi
        done
        if [ $FOUND -ne $DELETED ]; then
            sleep $SLEEP_DELAY
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
            STATUS_MSG="Domain=${DOMAIN} UserProfileName=${USER_PROFILE_NAME}"
            echo "status is ${STATUS}: ${STATUS_MSG}"
            if [ "$STATUS" == "InService" ]; then
                echo "Deleting User: ${STATUS_MSG}"
                aws --region $REGION sagemaker delete-user-profile \
                    --domain-id $DOMAIN \
                    --user-profile-name $USER_PROFILE_NAME
            elif [ "$STATUS" == "Pending" ]; then
                :
            elif [ "$STATUS" == "Deleting" ]; then
                :
            elif [ "$STATUS" == "Deleted" ]; then
                let DELETED+=1
            else
                echo "Unknown status \"$STATUS\": ${PROFILE}"
            fi
        done
        if [ $FOUND -ne $DELETED ]; then
            sleep $SLEEP_DELAY
        fi
    done

    echo "Deleting Domain: Domain=${DOMAIN}"
    aws --region $REGION sagemaker delete-domain \
        --domain-id $DOMAIN \
        --retention-policy HomeEfsFileSystem=Retain
done


IFS=$OLD_IFS
