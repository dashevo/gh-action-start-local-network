#!/bin/bash

set -eax

cmd_usage="Init local node

Usage: init-local-node.sh <path-to-package.json> [options]
  <path-to-package.json> must be an absolute path including file name

  Options:
  --override-major-version    - major version to use
  --override-minor-version    - minor version to use
  --dapi-branch               - dapi branch to be injected into mn-bootstrap
  --drive-branch              - drive branch to be injected into mn-bootstrap
  --sdk-branch                - Dash SDK (DashJS) branch to be injected into mn-bootstrap
"

PACKAGE_JSON_PATH="$1"

if [ -z "$PACKAGE_JSON_PATH" ]
then
  echo "Path to package.json is not specified"
  echo ""
  echo "$cmd_usage"
  exit 1
fi

for i in "$@"
do
case ${i} in
    -h|--help)
        echo "$cmd_usage"
        exit 0
    ;;
    --override-major-version=*)
    major_version="${i#*=}"
    ;;
    --override-minor-version=*)
    minor_version="${i#*=}"
    ;;
    --dapi-branch=*)
    dapi_branch="${i#*=}"
    ;;
    --drive-branch=*)
    drive_branch="${i#*=}"
    ;;
    --dashmate-branch=*)
    dashmate_branch="${i#*=}"
    ;;
    --sdk-branch=*)
    sdk_branch="${i#*=}"
    ;;
esac
done

# Define variables

DIR="$( cd -P "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
#CURRENT_VERSION=$("$DIR"/get-release-version "$PACKAGE_JSON_PATH" "$major_version")
#MN_RELEASE_LINK=$("$DIR"/get-github-release-link "$PACKAGE_JSON_PATH" dashevo/mn-bootstrap "$major_version" "$minor_version")
#
#echo "Current version: ${CURRENT_VERSION}";

# Create temp dir
TMP="$DIR"/../tmp
rm -rf "$TMP"
mkdir "$TMP"

# Download dapi from defined branch
#mn_bootstrap_dapi_options="--dapi-image-build-path="
#if [ -n "$dapi_branch" ]
#then
#  echo "Cloning DAPI from branch $dapi_branch"
#  cd "$TMP"
#  git clone https://github.com/dashevo/dapi.git
#  cd "$TMP"/dapi
#  git checkout "$dapi_branch"
#  mn_bootstrap_dapi_options="--dapi-image-build-path=$TMP/dapi"
#  echo "mn_bootstrap_dapi_options=--dapi-image-build-path=$TMP/dapi" >> $GITHUB_ENV
#fi

# Download drive from defined branch
#mn_bootstrap_drive_options="--drive-image-build-path="
#if [ -n "$drive_branch" ]
#then
#  echo "Cloning Drive from branch $drive_branch"
#  cd "$TMP"
#  git clone https://github.com/dashevo/drive.git --single-branch --branch $drive_branch
#  cd "$TMP"/drive
#  git status
#  git checkout "$drive_branch"
#  # docker build -t drive:local --load .
#  mn_bootstrap_drive_options="--drive-image-build-path=$TMP/drive"
#  echo "mn_bootstrap_drive_options=--drive-image-build-path=$TMP/drive" >> $GITHUB_ENV
#fi

# Download and install mn-bootstrap
echo "Installing mn-bootstrap"
cd "$TMP"
git clone https://github.com/dashevo/mn-bootstrap.git --single-branch --branch $dashmate_branch
cd "$TMP"/mn-bootstrap


#echo "$MN_RELEASE_LINK"
#curl -L "$MN_RELEASE_LINK" > "$TMP"/mn-bootstrap.tar.gz
#mkdir "$TMP"/mn-bootstrap && tar -C "$TMP"/mn-bootstrap -xvf "$TMP"/mn-bootstrap.tar.gz
#MN_RELEASE_DIR="$(ls "$TMP"/mn-bootstrap)"
#cd "$TMP"/mn-bootstrap/"$MN_RELEASE_DIR"

npm ci
npm link

if [ -n "$sdk_branch" ]
then
  echo "Installing Dash SDK from branch $sdk_branch"
  npm i "github:dashevo/DashJS#$sdk_branch"
fi

if [ -n "$drive_branch" ]
then
  echo "Cloning Drive from branch $drive_branch"
  cd "$TMP"
  git clone https://github.com/strophy/js-drive.git --single-branch --branch $drive_branch drive
  cd "$TMP"/drive
  #docker build -t drive_abci:local --load .
  # --cache-from --cache-to
  mn config:set --config=local platform.drive.abci.docker.build.path $TMP/drive
fi

if [ -n "$dapi_branch" ]
then
  echo "Cloning DAPI from branch $dapi_branch"
  cd "$TMP"
  git clone https://github.com/strophy/dapi.git --single-branch --branch $dapi_branch dapi
  cd "$TMP"/dapi
  #docker build -t dapi_api:local --load .
  # --cache-from --cache-to
  mn config:set --config=local platform.dapi.api.docker.build.path $TMP/dapi
fi

# Setup node for local node mn-bootstrap
echo "Setting up a local node"

# Set number of nodes
NODE_COUNT=3

mn config:set --config=local environment development
mn config:set --config=local platform.drive.abci.log.stdout.level trace


#if [[ $CURRENT_VERSION == "0.19"* ]]
#then
mn setup local --node-count="$NODE_COUNT" | tee setup.log
CONFIG="local_1"
MINER_CONFIG="local_seed"
#else
#  exit 1
#fi

mn config:set --config="$MINER_CONFIG" core.miner.enable true
mn config:set --config="$MINER_CONFIG" core.miner.interval 60s

FAUCET_PRIVATE_KEY=$(grep -m 1 "Private key:" setup.log | awk '{printf $4}')
#FAUCET_PRIVATE_KEY=$(echo "$OUTPUT" | grep -m 1 "Private key:" | awk '{printf $4}')
DPNS_CONTRACT_ID=$(mn config:get --config="$CONFIG" platform.dpns.contract.id)
DPNS_CONTRACT_BLOCK_HEIGHT=$(mn config:get --config="$CONFIG" platform.dpns.contract.blockHeight)
DPNS_TOP_LEVEL_IDENTITY_ID=$(mn config:get --config="$CONFIG" platform.dpns.ownerId)
DPNS_TOP_LEVEL_IDENTITY_PRIVATE_KEY=$(grep -m 1 "HD private key:" setup.log | awk '{$1=""; printf $5}')
#DPNS_TOP_LEVEL_IDENTITY_PRIVATE_KEY=$(echo "$OUTPUT" | grep -m 1 "HD private key:" | awk '{$1=""; printf $5}')

echo "Node is configured:"

echo "FAUCET_PRIVATE_KEY: ${FAUCET_PRIVATE_KEY}"
echo "DPNS_CONTRACT_ID: ${DPNS_CONTRACT_ID}"
echo "DPNS_CONTRACT_BLOCK_HEIGHT: ${DPNS_CONTRACT_BLOCK_HEIGHT}"
echo "DPNS_TOP_LEVEL_IDENTITY_ID: ${DPNS_TOP_LEVEL_IDENTITY_ID}"
echo "DPNS_TOP_LEVEL_IDENTITY_PRIVATE_KEY: ${DPNS_TOP_LEVEL_IDENTITY_PRIVATE_KEY}"


#Start mn-bootstrap
echo "Starting mn-bootstrap"
#if [[ $CURRENT_VERSION == "0.19"* ]]
#then
mn group:start "$mn_bootstrap_dapi_options" "$mn_bootstrap_drive_options" --wait-for-readiness
#else
#  exit 1
#fi

#Export variables
#export CURRENT_VERSION
export FAUCET_PRIVATE_KEY
export DPNS_TOP_LEVEL_IDENTITY_PRIVATE_KEY
export DPNS_TOP_LEVEL_IDENTITY_ID
export DPNS_CONTRACT_ID
export DPNS_CONTRACT_BLOCK_HEIGHT

if [[ -n $GITHUB_ACTIONS ]]
then
  #echo "current-version=$CURRENT_VERSION" >> $GITHUB_ENV
  echo "faucet-private-key=$FAUCET_PRIVATE_KEY" >> $GITHUB_ENV
  echo "dpns-top-level-identity-private-key=$DPNS_TOP_LEVEL_IDENTITY_PRIVATE_KEY" >> $GITHUB_ENV
  echo "dpns-top-level-identity-id=$DPNS_TOP_LEVEL_IDENTITY_ID" >> $GITHUB_ENV
  echo "dpns-contract-id=$DPNS_CONTRACT_ID" >> $GITHUB_ENV
  echo "dpns-contract-block-height=$DPNS_CONTRACT_BLOCK_HEIGHT" >> $GITHUB_ENV
fi
