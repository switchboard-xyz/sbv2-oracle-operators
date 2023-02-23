#!/bin/bash

# Google cloud platform utils to assist setting up your cloud environment
# TODO List:
# - Verify gcloud is installed and authenticated
# - Keypair / Service Account rotation

set -e
stty sane # dont show backspace char during prompts

# Imports
script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
# root_dir="$(dirname "$script_dir")"
. "$script_dir/env_utils.sh"

function load_gcp_project() {
    ## Get Project Name
    project=$1
    if [ -z "$project" ];
    then
        read -rp "Enter the name for the google cloud project (Ex. switchboard-oracle-cluster): " project
    fi
    project=$(echo "${project// /-}" | awk '{print tolower($0)}') # Replace spaces with dashes and make lower case

    gcloud config set project "$project" > /dev/null 2>&1;

    # TODO: Test this loads env variables correctly
    load_project_env "$project"
}


function setup_gcp_project() {
    load_gcp_project "$1"
    echo -e "project name: $project"
    ## Create GCP Project
    if gcloud projects list | grep -q "^${project}\s"; 
    then
        echo -e "\ngcloud project already exists: ${project}"
    else
        echo -e "\nCreating gcloud project: ${project}"
        gcloud projects create "$project"
    fi
    gcloud config set project "$project"  > /dev/null 2>&1; ## TODO: Remove when each command explicitly sets project
    
    # Save project name in env file
    save_project_env_value "$project" "PROJECT" "$project"

    # Enable billing
    echo -e "\nhttps://console.cloud.google.com/billing/enable?project=$project"
    read -rp "Have you enabled billing on this project ($project)? (y/n)? " answer
    case ${answer:0:1} in
        y|Y )
        ;;
        * )
            echo "User Exited"
            exit 0
        ;;
    esac

    ## Enable Required Services
    printf "\n########## Enabling GCP Services ##########\n"
    gcloud services enable compute.googleapis.com --project "$project" > /dev/null
    gcloud services enable container.googleapis.com --project "$project" > /dev/null
    gcloud services enable iamcredentials.googleapis.com --project "$project" > /dev/null
    gcloud services enable secretmanager.googleapis.com --project "$project" > /dev/null
}

function get_region() {
    load_gcp_project "$1"

    ## Set Default Region/Zone
    region=$(gcloud compute project-info describe --project "$project" | grep -A1 "google-compute-default-region" | tail -n 1 | cut -d ":" -f2- | awk '{$1=$1};1')
    zone=$(gcloud compute project-info describe --project "$project"  | grep -A1 "google-compute-default-zone" | tail -n 1 | cut -d ":" -f2- | awk '{$1=$1};1')

    if [[ -z "$region"  ||  -z "$zone" ]]
    then 
        echo "Failed to get region for project $project"
        exit 1
    fi
}


function set_region() {
    load_gcp_project "$1"

    ## Set Default Region/Zone
    region=$(gcloud compute project-info describe --project "$project" | grep -A1 "google-compute-default-region" | tail -n 1 | cut -d ":" -f2- | awk '{$1=$1};1')
    zone=$(gcloud compute project-info describe --project "$project"  | grep -A1 "google-compute-default-zone" | tail -n 1 | cut -d ":" -f2- | awk '{$1=$1};1')
    if [[ -z "$region"  ||  -z "$zone" ]]
    then 
    PS3="Enter a number to select your clusters region: "
    select region in us-east1 us-central1 us-west1 europe-north1 europe-west1 asia-east1 asia-southeast1 asia-east2
    do
        case $region in
        us-east1)
            region="us-east1"
            zone="us-east1-b"
            break
            ;;
        us-central1)
            region="us-central1"
            zone="us-central1-a"
            break
            ;;
        us-west1)
            region="us-west1"
            zone="us-west1-a"
            break
            ;;
        europe-north1)
            region="europe-north1"
            zone="europe-north1-a"
            break
            ;;
        europe-west1)
            region="europe-west1"
            zone="europe-west1-b"
            break
            ;;
        asia-east1)
            region="asia-east1"
            zone="asia-east1-a"
            break
            ;;
        asia-southeast1)
            region="asia-southeast1"
            zone="asia-southeast1-a"
            break
            ;;
        asia-east2)
            region="asia-east2"
            zone="asia-east2-a"
            break
            ;;
        *) 
            echo "Invalid option $REPLY"
            ;;
        esac
    done
    gcloud compute project-info add-metadata --metadata google-compute-default-region=$region,google-compute-default-zone=$zone --project "$project"
    else 
    echo -e "project default region ($region) and zone ($zone) already configured"
    fi

    # Save env values
    save_project_env_value "$project" "DEFAULT_REGION" "$region"
    save_project_env_value "$project" "DEFAULT_ZONE" "$zone"
}

function create_service_account() {
    load_gcp_project "$1"

    service_account_display_name=$2
    if [ -z "$service_account_display_name" ];
    then
        service_account_display_name="Oracle Svc Account"
    fi

    ## Create Service Account
    service_account_name=$(echo "${service_account_display_name// /-}" | awk '{print tolower($0)}') # Replace spaces with dashes and make lower case
    service_account_file="gcp/$project/secrets/$service_account_name.private-key.json"
    service_account_email="${service_account_name}@${project}.iam.gserviceaccount.com"
    if gcloud iam service-accounts list --project "$project" | grep -q "${service_account_email}\s"; 
    then
        echo -e "service account already exists: ${service_account_email}"
    else
        echo -e "Creating service account: ${service_account_name}"
        gcloud iam service-accounts create "$service_account_name" --display-name="$service_account_display_name" --project "$project"
    fi
    while true; do
    if [ ! -s "$service_account_file" ]
    then
        mkdir -p secrets
        if ! gcloud iam service-accounts keys create "$service_account_file" --iam-account="$service_account_email" --project "$project"; then
        echo "failed to create new svc-account key and output file is empty - deleting and recreating svc-account key"
        lastKeyId=$(gcloud iam service-accounts keys list --iam-account="$service_account_email" | awk 'NR==2' | grep -o "^\w*\b" | tr -d '\n')
        gcloud iam service-accounts keys delete "$lastKeyId" --iam-account="$service_account_email" --project "$project"
        continue
        fi
    fi
    break
    done
    service_account_base64=$(base64 -i "$service_account_file")

    # Save env values
    save_project_env_value "$project" "SERVICE_ACCOUNT_EMAIL" "$service_account_email"
    save_project_env_value "$project" "SERVICE_ACCOUNT_BASE64" "$service_account_base64"
}

function create_secret() {
    load_gcp_project "$1"

    secret_name=$2
    if [ -z "$secret_name" ];
    then
        secret_name="oracle-payer-secret"
    fi

    svc_account_email=$3
    if [ -z "$svc_account_email" ];
    then
        svc_account_email=$SERVICE_ACCOUNT_EMAIL
        if [ -z "$svc_account_email" ];
        then
            echo "failed to provide service account email that will have access to this secret"
            exit 1
        fi
    fi

    ## Create Keypair Secret
    if gcloud secrets list --project "$project" | grep -q "^${secret_name}\s"; 
    then
    echo -e "payer secret already exists: ${secret_name}"
    else
    echo -e "Creating payer secret: ${secret_name}"
    secret_path=$4
    if [ -z "$secret_path" ];
    then
    while 
        read -rp "Enter the path to your payer keypair: " payer_keypair_path
        do    
        if [[ -f "$payer_keypair_path" ]]
        then 
            gcloud secrets create $secret_name --replication-policy="automatic" --data-file="$payer_keypair_path" --project "$project"
            sleep 3
            gcloud secrets add-iam-policy-binding $secret_name --member="serviceAccount:${service_account_email}" --role="roles/secretmanager.secretAccessor" --project "$project" > /dev/null
            break
        else 
            echo "File does not exists, please try again."
            continue
        fi
    done
    else
        gcloud secrets create $secret_name --replication-policy="automatic" --data-file="$secret_path" --project "$project"
        sleep 3
        gcloud secrets add-iam-policy-binding $secret_name --member="serviceAccount:${service_account_email}" --role="roles/secretmanager.secretAccessor" --project "$project" > /dev/null
    fi
    fi

    google_payer_secret_path="$(gcloud secrets list --uri --filter=${secret_name} --project "$project" | cut -c41- | tr -d '\n')/versions/latest"

    # Save env values
    save_project_env_value "$project" "SECRET_NAME" "$secret_name"
    save_project_env_value "$project" "GOOGLE_PAYER_SECRET_PATH" "$google_payer_secret_path"
}

function create_network_ip() {
    load_gcp_project "$1"

    external_ip_name=$2
    if [ -z "$external_ip_name" ];
    then
        external_ip_name="oracle-external-ip"
    fi

    region="$DEFAULT_REGION"
    if [ -z "$region" ];
    then
        set_region "$project"
        load_project_env "$project"
        if [ -z "$region" ];
        then
            echo "Failed to get region for project $project"
            exit 1
        fi
    fi

    if gcloud compute addresses list  --project "$project" | grep -q "^${external_ip_name}\s"; 
    then
    echo -e "external ipv4 address already exists: ${external_ip_name}"
    else
    echo -e "Creating external ipv4 address: ${external_ip_name}"
    gcloud compute addresses create ${external_ip_name} --region "$region" --project "$project"
    fi
    external_ip=$(gcloud compute addresses list --project "$project" | grep "^${external_ip_name}\s" | grep -oE "((1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])\.){3}(1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])")

    # Save env values
    save_project_env_value "$project" "EXTERNAL_IP" "$external_ip"
}

function create_bucket(){
    load_gcp_project "$1"

    storage_bucket_name=$2
    if [ -z "$storage_bucket_name" ];
    then
        storage_bucket_name="${project}-oracle-configs"
    fi
    storage_bucket_path="$storage_bucket_name:configs.json"
    full_storage_bucket_name="gs://$project-oracle-configs"

    if gsutil ls | grep -q "^gs://$storage_bucket_name/"; 
    then
        echo -e "storage bucket already exists: ${storage_bucket_name}"
    else
        echo -e "Creating storage bucket: ${storage_bucket_name}"
        gsutil mb -p "$project" -l "$region" "$full_storage_bucket_name"
        gsutil iam ch serviceAccount:"$service_account_email":legacyBucketReader "$full_storage_bucket_name"
    fi
    storage_bucket_path="$storage_bucket_name:configs.json"

    # Save env values
    save_project_env_value "$project" "GCP_CONFIG_BUCKET" "$storage_bucket_path"
}

function create_cluster() {
    load_gcp_project "$1"

    cluster_name=$2
    if [ -z "$cluster_name" ];
    then
        cluster_name="switchboard-cluster"
    fi

    region="$DEFAULT_REGION"
    if [ -z "$region" ];
    then
        set_region "$project"
        load_project_env "$project"
        if [ -z "$region" ];
        then
            echo "Failed to get region for project $project"
            exit 1
        fi
    fi

    service_account_email="$SERVICE_ACCOUNT_EMAIL"
    if [ -z "$service_account_email" ];
    then
        echo "Failed to get service account email for project $project"
        exit 1
    fi

    ## Start container and save credentials
    if gcloud container clusters list --project "$project" | grep -q "^${cluster_name}\s"; 
    then
    echo -e "kubernetes cluster already exists: ${cluster_name}"
    else
    echo -e "Creating kubernetes cluster: ${cluster_name}"
    gcloud container clusters create-auto $cluster_name --service-account="$service_account_email" --region "$region" --project "$project"
    fi
    gcloud container clusters get-credentials $cluster_name --project "$project" --region "$region"
    
    # Save env values
    save_project_env_value "$project" "CLUSTER_NAME" "$cluster_name"
}

function set_cluster() {
    load_gcp_project "$1"

    cluster_name=$2
    if [ -z "$cluster_name" ];
    then
        cluster_name="switchboard-cluster"
    fi

    get_region "$1"
    # region="$DEFAULT_REGION"
    if [ -z "$region" ];
    then
        echo "Failed to get region for project $project"
        exit 1
    fi

    gcloud container clusters get-credentials $cluster_name --project "$project" --region "$region"

    echo -e "K8s credentials set for ${project}.env, cluster ${cluster_name}, in region ${region}"

    save_cluster_env_value "$project" "$cluster" "DEFAULT_REGION" "$region"
    save_cluster_env_value "$project" "$cluster" "DEFAULT_ZONE" "$zone"
    save_cluster_env_value "$project" "$cluster" "CLUSTER_NAME" "$cluster_name"
}