#!/bin/bash

if [ $# -lt 3 ]; then
    echo "Usage: $0 [APP_ROOT_DIR] [DOCKER_IMAGE_NAME] [PRIVATE_KEY_FILE]"
    exit 1
fi

export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-us-east-1}

if [ -z "${AWS_ACCESS_KEY_ID}" -o \
     -z "${AWS_SECRET_ACCESS_KEY}" -o \
     -z "${AWS_DEFAULT_REGION}" ]; then
    echo "Please set following env vars and try again"
    echo " - AWS_ACCESS_KEY_ID"
    echo " - AWS_SECRET_ACCESS_KEY"
    exit 1
fi

export DEPLOYER_ROOT_DIR="$(cd $(dirname $0) && echo $PWD)"
export APP_ROOT_DIR="$(cd ${1} && echo $PWD)"
export DOCKER_IMAGE_NAME="$2"
export PRIVATE_KEY_FILE="$3"
export PATH="${DEPLOYER_ROOT_DIR}:${DEPLOYER_ROOT_DIR}/bin:$PATH"

. ${DEPLOYER_ROOT_DIR}/bin/support.sh

set -e

title "Deploying app from $APP_ROOT_DIR"

mesg "[Config]"
mesg " DEPLOYER_ROOT_DIR: $DEPLOYER_ROOT_DIR"
mesg " APP_ROOT_DIR:      $APP_ROOT_DIR"
mesg " DOCKER_IMAGE_NAME: $DOCKER_IMAGE_NAME"
mesg " PRIVATE_KEY_FILE:  $PRIVATE_KEY_FILE"

title "[Docker] Building app image ${DOCKER_IMAGE_NAME} from ${APP_ROOT_DIR}"
build-docker-image ${APP_ROOT_DIR} ${DOCKER_IMAGE_NAME}

title "[Docker] Pushing app image ${DOCKER_IMAGE_NAME}"
push-docker-image ${DOCKER_IMAGE_NAME}

${DEPLOYER_ROOT_DIR}/terraform/deploy.sh ${DOCKER_IMAGE_NAME} ${PRIVATE_KEY_FILE}
