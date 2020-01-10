#!/bin/bash -l
yell() { echo "$0: $*" >&2; }
die() { yell "$*"; exit 111; }
try() { "$@" || die "cannot $*"; }

if [[ "${ENVIRONMENT}" = "dev" ]]; then
    ANYPOINT_ENVIRONMENT="Sandbox"
elif [[ "${ENVIRONMENT}" = "qa" ]]; then
    ANYPOINT_ENVIRONMENT="QA"
elif [[ "${ENVIRONMENT}" = "prod" ]]; then
    ANYPOINT_ENVIRONMENT="Production"
fi

GIT_REPO=${GITHUB_REPOSITORY##*/}
ANYPOINT_LAYER=${GIT_REPO%%-*}
ANYPOINT_LAYER=${ANYPOINT_LAYER//sys/System}
ANYPOINT_LAYER=${ANYPOINT_LAYER//proc/Process}
ANYPOINT_LAYER=${ANYPOINT_LAYER//exp/Experience}
APP_NAME=${GIT_REPO##*api-}
ANYPOINT_LAYER_LOWERCASE=$(echo $ANYPOINT_LAYER | tr '[:upper:]' '[:lower:]')
ANYPOINT_ASSET_ID=$APP_NAME-$ANYPOINT_LAYER_LOWERCASE-api

#==========================================================
# Use branch name for the API instance label
#
api_instance_label=${GITHUB_REF##*/}
api_instance_label=${api_instance_label##*-}

#==========================================================
# Check if this API exists in API Manager
#
if [[ "$ANYPOINT_LAYER" = "Experience" ]]; then
    response=$(anypoint-cli api-mgr api list --environment $ANYPOINT_ENVIRONMENT --assetId $ANYPOINT_ASSET_ID --instanceLabel $api_instance_label --fields 'Instance ID,Asset Version' | grep '^[0-9]\+')
    if [[ "$?" = "0" ]]; then
        ANYPOINT_API_ID=${response%% *}
        echo Using existing API ID: $ANYPOINT_API_ID
        CURRENT_ASSET_VERSION=$(echo $response | grep -o "[0-9]\+\.[0-9]\+\.[0-9]\+")
        if [[ "$CURRENT_ASSET_VERSION" != "$API_VERSION" ]]; then
            echo Updating Asset Version from $CURRENT_ASSET_VERSION to $API_VERSION
            response=$(anypoint-cli api-mgr api change-specification --environment $ANYPOINT_ENVIRONMENT $ANYPOINT_API_ID $API_VERSION)
            echo $response
        fi
    else
        # if API doesn't exist, create it
        response=$(anypoint-cli api-mgr api manage --environment $ANYPOINT_ENVIRONMENT --type raml -m true --deploymentType rtf --apiInstanceLabel $api_instance_label $ANYPOINT_ASSET_ID $API_VERSION)

        if [[ $response =~ ^Error:.*$ ]]; then
            die "$response"
        fi

        # response expected to be:: Created new API with ID: 15811945
        ANYPOINT_API_ID=${response##*: }
        echo Created new API ID: $ANYPOINT_API_ID
    fi
    echo ::set-env name=API_ID::$ANYPOINT_API_ID
fi
