# Switchboard V2 Oracle Operators

TODO:

- Need to define schema that allows managing multiple clusters/envs for a single
  GCP project
- Maybe: PROJECT_NAME.CLUSTER_NAME.env
- Maybe: gcp/PROJECT_NAME/CLUSTER with project `.env` in gcp/PROJECT_NAME and
  cluster `.env` in gcp/PROJECT_NAME/CLUSTER
- Maybe: have `sbv2.env` with LATEST_ORACLE_IMAGE and LATEST_CRANK_IMAGE. Need
  bash script for github releases when this gets updated
- Then `.env` files get loaded in the following order, `sbv2.env` > project
  `.env` > cluster `.env`

## Create GCP Oracle

```bash
./create-gcp-cluster.sh [GCP_PROJECT_NAME] [CHAIN] [QUEUE_KEY] [PAYER_KEYPAIR_PATH]
```

where,

- GCP_PROJECT_NAME is the google cloud platform project name
- CHAIN is either solana, aptos, or near
- QUEUE you are creating the oracle for
- PAYER_KEYPAIR_PATH that will be used for transaction cost and added to GCP
  secret manager
