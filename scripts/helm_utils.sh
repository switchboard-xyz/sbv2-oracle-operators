#!/bin/bash

# Helm utils for managing your cluster such as build, upgrade, deploy

# Imports
script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
. "$script_dir/env_utils.sh"
. "$script_dir/gcp_utils.sh"

function verify_kubectl() {
    if ! kubectl --help > /dev/null 2>&1; then
        echo "This script requires kubectl to be installed"
        exit 1
    fi
}

function stream_logs() {
    ## Get Project Name
    project=$1
    if [ -z "$project" ];
    then
        echo "You must provide a valid GCP project in order to stream logs"
        exit 1
    fi
    load_gcp_project "$project"

    cluster_name=$2
    if [ -z "$cluster_name" ];
    then
        cluster_name=CLUSTER_NAME
        if [ -z "$cluster_name" ];
        then
            echo "You must provide a valid GCP project in order to stream logs"
            exit 1
        fi
    fi
    set_cluster "$project" "$cluster_name"

    while true; 
    do 
        kubectl logs -f -l app=oracle --all-containers --max-log-requests=100 --prefix=true;
    done
}

function build_helm() {
    load_gcp_project "$1"

    chain=$2
    if [[ "$chain" != "solana" && "$chain" != "aptos" && "$chain" != "near" ]]; then
        echo "CHAIN must be either solana, aptos, or near. Received $chain"
        exit 1
    fi

    cluster_name=$3
    if [ -z "$cluster_name" ];
    then
        cluster_name=CLUSTER_NAME
        if [ -z "$cluster_name" ];
        then
            echo "You must provide a valid GCP project in order to stream logs"
            exit 1
        fi
    fi
    set_cluster "$project" "$cluster_name"

    # TODO: Match chain to helm function
}

function build_solana_helm() {
    # Should have loaded env values by now but oh well
    load_gcp_project "$1"

    # TODO: Load the latest docker image. Should we keep this in a markdown file at the workspace root?

    if [[ -z "${CLUSTER}" ]]; then
        echo "failed to set CLUSTER"
        exit 1
    elif [[ "$CLUSTER" != "devnet" && "$CLUSTER" != "mainnet-beta" && "$CLUSTER" != "localnet" ]]; then
        echo "invalid CLUSTER ($CLUSTER) - [devnet, mainnet-beta, or localnet]"
        exit 1
    fi
    if [[ -z "${RPC_URL}" ]]; then
        echo "failed to set RPC_URL"
        exit 1
    fi
    if [[ -z "${WS_URL}" ]]; then
        WS_URL=""
    fi
    if [[ -z "${BACKUP_MAINNET_RPC}" ]]; then
        BACKUP_MAINNET_RPC="https://api.mainnet-beta.solana.com" # TODO: Update
    fi
    if [[ -z "${ORACLE_KEY}" ]]; then
        echo "failed to set ORACLE_KEY"
        exit 1
    fi
    if [[ -z "${HEARTBEAT_INTERVAL}" ]]; then
        HEARTBEAT_INTERVAL="15"
    fi
    if [[ -z "${GOOGLE_PAYER_SECRET_PATH}" ]]; then
        echo "failed to set GOOGLE_PAYER_SECRET_PATH"
        exit 1
    fi
    if [[ -z "${GCP_CONFIG_BUCKET}" ]]; then
        GCP_CONFIG_BUCKET="oracle-configs:configs.json"
    fi
    if [[ -z "${SERVICE_ACCOUNT_BASE64}" ]]; then
        echo "failed to set SERVICE_ACCOUNT_BASE64"
        exit 1
    fi
    if [[ -z "${EXTERNAL_IP}" ]]; then
        echo "failed to set EXTERNAL_IP"
        exit 1
    fi
    if [[ -z "${PAGERDUTY_EVENT_KEY}" ]]; then
        PAGERDUTY_EVENT_KEY=""
    fi
    if [[ -z "${GRAFANA_HOSTNAME}" ]]; then
        echo "failed to set GRAFANA_HOSTNAME"
        exit 1
    fi
    if [[ -z "${GRAFANA_ADMIN_PASSWORD}" ]]; then
        GRAFANA_ADMIN_PASSWORD="${GRAFANA_ADMIN_PASSWORD:-SbCongraph50!}"
    fi
    if [[ -z "${GRAFANA_TLS_CRT}" ]]; then
        echo "failed to set GRAFANA_TLS_CRT"
        exit 1
    fi
    if [[ -z "${GRAFANA_TLS_KEY}" ]]; then
        echo "failed to set GRAFANA_TLS_KEY"
        exit 1
    fi
    if [[ -z "${METRICS_EXPORTER}" ]]; then
        METRICS_EXPORTER="${METRICS_EXPORTER:-prometheus}"
    elif [[ "$METRICS_EXPORTER" != "prometheus" && "$CLUSTER" != "gcp" && "$CLUSTER" != "opentelemetry-collector" ]]; then
        echo "invalid METRICS_EXPORTER ($METRICS_EXPORTER) - [prometheus, gcp, or opentelemetry-collector]"
        exit 1
    fi

    # Copy current solana helm chart
    output_path="gcp/${project}/"
    cp -r "${script_dir}/helm/solana-oracle" "$output_path"

    files=(
        "$outputPath/values.yaml"
    )

    for f in "${files[@]}"; do
    PAGERDUTY_EVENT_KEY="$PAGERDUTY_EVENT_KEY" \
    METRICS_EXPORTER="$METRICS_EXPORTER" \
    GRAFANA_ADMIN_PASSWORD="$GRAFANA_ADMIN_PASSWORD"\
    envsubst '$CLUSTER $RPC_URL $WS_URL $BACKUP_MAINNET_RPC $ORACLE_KEY $HEARTBEAT_INTERVAL $GOOGLE_PAYER_SECRET_PATH $GCP_CONFIG_BUCKET $SERVICE_ACCOUNT_BASE64 $EXTERNAL_IP $PAGERDUTY_EVENT_KEY $GRAFANA_HOSTNAME $GRAFANA_ADMIN_PASSWORD $GRAFANA_TLS_CRT $GRAFANA_TLS_KEY $METRICS_EXPORTER' < "$f" \
    | tee "$outputPath/tmp.txt" \
    > /dev/null ;
    cat "$outputPath/tmp.txt" > "$f";
    done

    rm "$outputPath/tmp.txt"

    # TODO: Output command to deploy helm charts
}