#!/bin/bash

# Switchboard V2 Utils to assist creating and managing an oracle account
# TODO List:
# - Create oracle
# - Fund oracle
# - Oracle metrics

function verify_cli() {
    if ! sbv2 --help > /dev/null 2>&1; then
        printf "This script uses the switchboard CLI, and it isn't installed - please install the CLI with the following command and retry:\n\tnpm i -g @switchboard-xyz/cli"
        exit 1
    fi
}