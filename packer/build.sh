#!/bin/bash

set -e

[ -d "${DEPLOYER_ROOT_DIR}" ] || export DEPLOYER_ROOT_DIR="$(cd $(dirname $(dirname $0)) && echo $PWD)"

. ${DEPLOYER_ROOT_DIR}/bin/support.sh

title "[Packer] Creating base AMI"

cd ${DEPLOYER_ROOT_DIR}/packer/
packer validate template.json
packer build -force $@ template.json
