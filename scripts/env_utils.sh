#!/bin/bash

# Env Utils to assist with managing your oracle environment
script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# .env loading in the shell
function load_project_env() {
    project=$1
    if [ -z "$project" ];
    then
        echo "failed to provide project to save env value"
        exit 1
    fi
    envFile=$(realpath ./gcp/"$project"/.env)

    set -a
    # source "$envFile"
    [ -f "$envFile" ] && . "$envFile" 
    set +a
}

# Given a GCP project, save a key, value pair to its env file in the current working directory
# Arg1: GCP Project name, (Ex: my-switchboard-oracle)
# Arg2: Env key, (Ex: GOOGLE_PAYER_SECRET_PATH)
# Arg3: Env value, (Ex: projects/111111111111/secrets/oracle-payer-secret/versions/latest)
function save_project_env_value(){
    project=$1
    if [ -z "$project" ];
    then
        echo "failed to provide project to save env value"
        exit 1
    fi
    envFile=$(realpath ./gcp/"$project"/.env)
    touch "$envFile"

    key=$2
    if [ -z "$key" ];
    then
        echo "failed to provide key to save env value"
        exit 1
    fi

    value=$3
    if [ -z "$value" ];
    then
        echo "failed to provide value to save env value"
        exit 1
    fi

    existingLineRegex="^$key=.*$"
    newLine=$(printf '%s="%s"\n' "$key" "$value")

    if grep "$existingLineRegex" "$envFile"
    then
        sed -E -i '' "s!$existingLineRegex!$newLine!g" "$envFile"
    else
        echo "$newLine" >> "$envFile"
    fi
}



# .env loading in the shell
function load_cluster_env() {
    project=$1
    if [ -z "$project" ];
    then
        echo "failed to provide project to save env value"
        exit 1
    fi
    cluster=$2
    if [ -z "$cluster" ];
    then
        echo "failed to provide cluster to save env value"
        exit 1
    fi
    envFile=$(realpath ./gcp/"$project"/"$cluster".env)

    set -a
    # source "$envFile"
    [ -f "$envFile" ] && . "$envFile" 
    set +a
}

# Given a GCP project, save a key, value pair to its env file in the current working directory
# Arg1: GCP Project name, (Ex: my-switchboard-oracle)
# Arg2: Env key, (Ex: GOOGLE_PAYER_SECRET_PATH)
# Arg3: Env value, (Ex: projects/111111111111/secrets/oracle-payer-secret/versions/latest)
function save_cluster_env_value(){
    project=$1
    if [ -z "$project" ];
    then
        echo "failed to provide project to save env value"
        exit 1
    fi
    cluster=$2
    if [ -z "$cluster" ];
    then
        echo "failed to provide cluster to save env value"
        exit 1
    fi
    envFile=$(realpath ./gcp/"$project"/"$cluster".env)
    touch "$envFile"

    key=$3
    if [ -z "$key" ];
    then
        echo "failed to provide key to save env value"
        exit 1
    fi

    value=$4
    if [ -z "$value" ];
    then
        echo "failed to provide value to save env value"
        exit 1
    fi

    existingLineRegex="^$key=.*$"
    newLine=$(printf '%s="%s"\n' "$key" "$value")

    if grep "$existingLineRegex" "$envFile"
    then
        sed -E -i '' "s!$existingLineRegex!$newLine!g" "$envFile"
    else
        echo "$newLine" >> "$envFile"
    fi
}