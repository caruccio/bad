#!/bin/bash

set -e

[ -d "${DEPLOYER_ROOT_DIR}" ] || export DEPLOYER_ROOT_DIR="$(cd $(dirname $(dirname $0)) && echo $PWD)"

. ${DEPLOYER_ROOT_DIR}/bin/support.sh

title "[Terraform] Deploying app instance"

if [ $# -lt 2 ]; then
    mesg "Usage: $0 [DOCKER_IMAGE_NAME] [PRIVATE_KEY_FILE] <AMI_ID>"
    exit 1
fi

DOCKER_IMAGE_NAME="${1}"
PRIVATE_KEY_FILE="${2}"

if ! [ -e "${PRIVATE_KEY_FILE}" ]; then
    mesg "Usage: $0 [DOCKER_IMAGE_NAME] [PRIVATE_KEY_FILE] <AMI_ID>"
    exit 1
fi

if [ -z "${AWS_KEY_NAME}" ]; then
    AWS_KEY_NAME=$(find-key-name ${PRIVATE_KEY_FILE})
    if [ -z "$AWS_KEY_NAME" ]; then
        mesg "Is your SSH key properly installed in AWS?"
        mesg "Check it here: https://console.aws.amazon.com/ec2/v2/home?#KeyPairs"
        exit 1
    fi
fi

if [ -z "${AWS_KEY_NAME}" ]; then
    mesg Missing env var AWS_KEY_NAME
    exit 1
fi

if [ $# -gt 2 ]; then
    AMI_ID=${1}
else
    #
    # This only makes sense if we had app-specific bits added to AMI
    #
    #MANIFEST=${DEPLOYER_ROOT_DIR}/packer/manifest.json
    #if ! [ -e "${MANIFEST}" ]; then
    #    echo "AMI_ID undefined"
    #    echo "Usage: $0 [DOCKER_IMAGE_NAME] [PRIVATE_KEY_FILE] <AMI_ID>"
    #    exit 1
    #fi
    #AMI_ID=$(python -c 'import sys, json; print json.load(sys.stdin)["builds"][0]["artifact_id"].split(":")[-1]' < $MANIFEST)

    AMI_ID=$(find-ami-id 'BAD - AppServer')

    if [ -z "$AMI_ID" ]; then
        mesg 'Unable to find ID of AMI "BAD - AppServer"'
        mesg 'Create one by running again this command with single parameter "build-ami"'
        exit 1
    fi

    mesg "Selected AMI $AMI_ID"
fi

cd ${DEPLOYER_ROOT_DIR}/terraform/
terraform validate .
terraform apply \
    -var docker_image_name=${DOCKER_IMAGE_NAME} \
    -var aws_ami=${AMI_ID} \
    -var aws_key_name=${AWS_KEY_NAME} \
    -var aws_region=${AWS_DEFAULT_REGION} \
    -var private_key_file=${PRIVATE_KEY_FILE} \
    .
