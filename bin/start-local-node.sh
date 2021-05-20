#!/bin/bash

set -ea

cmd_usage="Start local node

Usage: start-local-node [options]

  Options:
  --dapi-branch               - dapi branch to be injected into dashmate
  --drive-branch              - drive branch to be injected into dashmate
  --sdk-branch                - Dash SDK (DashJS) branch to be injected into dashmate
"

for i in "$@"
do
case ${i} in
    -h|--help)
        echo "$cmd_usage"
        exit 0
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

# Ensure $TMPDIR
if [ -z "$TMPDIR" ]; then
  TMPDIR="/tmp"
fi

# Define variables
DIR="$( cd -P "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Download and install dashmate

echo "Installing Dashmate from branch ${dashmate_branch}"

git clone --depth 1 --branch $dashmate_branch https://github.com/dashevo/dashmate.git "$TMPDIR/dashmate"

cd "$TMPDIR"/dashmate

npm ci
npm link

if [ -n "$sdk_branch" ]
then
  echo "Installing Dash SDK from branch $sdk_branch"
  npm i "github:dashevo/DashJS#$sdk_branch"
fi

# Build Drive from sources

if [ -n "$drive_branch" ]
then
  echo "Cloning Drive from branch $drive_branch"
  git clone --depth 1 --branch $drive_branch https://github.com/dashevo/js-drive.git "$TMPDIR/drive"
  dashmate config:set --config=local platform.drive.abci.docker.build.path "$TMPDIR/drive"

  #  Restore npm cache

  DRIVE_CACHE_HASH=$(sha1sum $TMPDIR/drive/package-lock.json | awk '{ print $1 }')
  "$DIR"/restore-cache "$TMPDIR/drive/docker/cache" "alpine-node-drive-$DRIVE_CACHE_HASH" "alpine-node-drive-"
fi

# Build DAPI from sources

if [ -n "$dapi_branch" ]
then
  echo "Cloning DAPI from branch $dapi_branch"
  git clone --depth 1 --branch $dapi_branch https://github.com/dashevo/dapi.git "$TMPDIR/dapi"
  dashmate config:set --config=local platform.dapi.api.docker.build.path "$TMPDIR/dapi"

  #  Restore npm cache

  DAPI_CACHE_HASH=$(sha1sum $TMPDIR/dapi/package-lock.json | awk '{ print $1 }')
  "$DIR"/restore-cache "$TMPDIR/dapi/docker/cache" "alpine-node-dapi-$DAPI_CACHE_HASH" "alpine-node-dapi-"
fi

# Update node software

dashmate update

# Setup local network

echo "Setting up a local network"

NODE_COUNT=3
CORE_MINER_INTERVAL=2.5m
DASHMATE_VERSION=$(jq -r '.version' $GITHUB_WORKSPACE/package.json)

if [[ DASHMATE_VERSION =~ ^0\.20.* ]]; then
  echo "in condition"
  #dashmate config:set --config=local core.miner.interval $CORE_MINER_INTERVAL
fi

dashmate config:set --config=local environment development
dashmate config:set --config=local platform.drive.abci.log.stdout.level trace

dashmate setup local --verbose --node-count="$NODE_COUNT" | tee setup.log

#  Save npm cache

if [ -n "$drive_branch" ]
then
  "$DIR"/save-cache "$TMPDIR/drive/docker/cache" "alpine-node-drive-$DRIVE_CACHE_HASH"
fi

if [ -n "$dapi_branch" ]
then
  "$DIR"/save-cache "$TMPDIR/dapi/docker/cache" "alpine-node-dapi-$DAPI_CACHE_HASH"
fi

CONFIG="local_1"

MINER_CONFIG="local_seed"

dashmate config:set --config="$MINER_CONFIG" core.miner.enable true
dashmate config:set --config="$MINER_CONFIG" core.miner.interval 60s

FAUCET_PRIVATE_KEY=$(grep -m 1 "Private key:" setup.log | awk '{printf $4}')
DPNS_CONTRACT_ID=$(dashmate config:get --config="$CONFIG" platform.dpns.contract.id)
DPNS_CONTRACT_BLOCK_HEIGHT=$(dashmate config:get --config="$CONFIG" platform.dpns.contract.blockHeight)
DPNS_TOP_LEVEL_IDENTITY_ID=$(dashmate config:get --config="$CONFIG" platform.dpns.ownerId)
DPNS_TOP_LEVEL_IDENTITY_PRIVATE_KEY=$(grep -m 1 "HD private key:" setup.log | awk '{$1=""; printf $5}')

echo "Local network is configured:"

echo "FAUCET_PRIVATE_KEY: ${FAUCET_PRIVATE_KEY}"
echo "DPNS_CONTRACT_ID: ${DPNS_CONTRACT_ID}"
echo "DPNS_CONTRACT_BLOCK_HEIGHT: ${DPNS_CONTRACT_BLOCK_HEIGHT}"
echo "DPNS_TOP_LEVEL_IDENTITY_ID: ${DPNS_TOP_LEVEL_IDENTITY_ID}"
echo "DPNS_TOP_LEVEL_IDENTITY_PRIVATE_KEY: ${DPNS_TOP_LEVEL_IDENTITY_PRIVATE_KEY}"

# Start dashmate

echo "Starting dashmate"

dashmate group:start --verbose --wait-for-readiness

# Export variables

echo "::set-output name=current-version::$CURRENT_VERSION"
echo "::set-output name=faucet-private-key::$FAUCET_PRIVATE_KEY"
echo "::set-output name=dpns-top-level-identity-private-key::$DPNS_TOP_LEVEL_IDENTITY_PRIVATE_KEY"
echo "::set-output name=dpns-top-level-identity-id::$DPNS_TOP_LEVEL_IDENTITY_ID"
echo "::set-output name=dpns-contract-id::$DPNS_CONTRACT_ID"
echo "::set-output name=dpns-contract-block-height::$DPNS_CONTRACT_BLOCK_HEIGHT"
