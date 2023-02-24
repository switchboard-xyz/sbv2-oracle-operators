#!/bin/bash
set -e
stty sane # dont show backspace char during prompts

# Create a GCP oracle for a given chain
# Arg1: GCP Project Name
# Arg2: Chain, solana, aptos, or near
# Arg3: Keypair path

# Imports
script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
. "$script_dir/scripts/env_utils.sh"
. "scripts/gcp_utils.sh"

if [ -z "$1" ];
then
    echo "Need to provide GCP project name as first arguement"
    exit 1
fi

chain=$2
if [[ "$chain" != "solana" && "$chain" != "aptos" && "$chain" != "near"  && "$chain" != "starknet" ]]; then
  echo "CHAIN must be either solana, aptos, or near. Received $chain"
  exit 1
fi

# secret_path=$4
# if [ -z "$secret_path" ];
# then
#     echo "Need to provide file path for oracle payer secret"
#     exit 1
# fi
# if [ ! -f "$secret_path" ];
# then
#     echo "provided secret path does not exist at ${secret_path}"
#     exit 1
# fi

create_service_account "$1" "$chain Oracle Svc Account"

# create_secret "$1" "$chain-oracle-payer-secret" "" "$secret_path"
