#!/bin/bash

echo Installing dependencies...
set -e

mkdir -p /bad/bin
cd /bad/bin

function fetch_archive()
{
    local filename="${1##*/}" ## basename
    curl -L "${1}" > $filename
    if [ "${filename/*.tar.gz/1}" == 1 ]; then
        tar xzvf $filename
    elif [ "${filename/*.zip/1}" == 1 ]; then
        unzip $filename
    fi
    rm $filename
}

fetch_archive https://github.com/openshift/source-to-image/releases/download/v1.1.7/source-to-image-v1.1.7-226afa1-linux-amd64.tar.gz
fetch_archive https://releases.hashicorp.com/packer/1.0.3/packer_1.0.3_linux_amd64.zip
fetch_archive https://releases.hashicorp.com/terraform/0.9.11/terraform_0.9.11_linux_amd64.zip
