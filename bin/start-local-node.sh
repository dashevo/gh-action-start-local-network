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
fi

# Build DAPI from sources

if [ -n "$dapi_branch" ]
then
  echo "Cloning DAPI from branch $dapi_branch"
  git clone --depth 1 --branch $dapi_branch https://github.com/dashevo/dapi.git "$TMPDIR/dapi"
  dashmate config:set --config=local platform.dapi.api.docker.build.path "$TMPDIR/dapi"
fi

# Update node software

dashmate update

# Setup local network

echo "Setting up a local network"

NODE_COUNT=3
MINER_INTERVAL=20s
DASHMATE_VERSION=$(jq -r '.version' ${TMPDIR}/dashmate/package.json)

echo "Using dashmate ${DASHMATE_VERSION}"

if [[ $DASHMATE_VERSION =~ ^0\.20* ]]; then
  dashmate setup local --verbose --node-count="$NODE_COUNT" --miner-interval="$MINER_INTERVAL" --debug-logs | tee setup.log
else
  dashmate config:set --config=local platform.drive.abci.log.stdout.level trace
  dashmate setup local --verbose --node-count="$NODE_COUNT" | tee setup.log
fi

CONFIG="local_1"

MINER_CONFIG="local_seed"

if [[ $DASHMATE_VERSION =~ ^0\.19* ]]; then
  echo "Enable miner"
  dashmate config:set --config="${MINER_CONFIG}" core.miner.enable true
  dashmate config:set --config="${MINER_CONFIG}" core.miner.interval 60s
fi

DPNS_CONTRACT_ID=$(dashmate config:get --config="$CONFIG" platform.dpns.contract.id)
DPNS_CONTRACT_BLOCK_HEIGHT=$(dashmate config:get --config="$CONFIG" platform.dpns.contract.blockHeight)
DPNS_TOP_LEVEL_IDENTITY_ID=$(dashmate config:get --config="$CONFIG" platform.dpns.ownerId)
DPNS_TOP_LEVEL_IDENTITY_PRIVATE_KEY=$(grep -m 1 "HD private key:" setup.log | awk '{$1=""; printf $5}')

echo "Local network is configured:"

echo "DPNS_CONTRACT_ID: ${DPNS_CONTRACT_ID}"
echo "DPNS_CONTRACT_BLOCK_HEIGHT: ${DPNS_CONTRACT_BLOCK_HEIGHT}"
echo "DPNS_TOP_LEVEL_IDENTITY_ID: ${DPNS_TOP_LEVEL_IDENTITY_ID}"
echo "DPNS_TOP_LEVEL_IDENTITY_PRIVATE_KEY: ${DPNS_TOP_LEVEL_IDENTITY_PRIVATE_KEY}"

echo "Mint 100 Dash to faucet address"

dashmate wallet:mint --verbose --config=local_seed 100 | tee mint.log

FAUCET_ADDRESS=$(grep -m 1 "Address:" mint.log | awk '{printf $3}')
FAUCET_PRIVATE_KEY=$(grep -m 1 "Private key:" mint.log | awk '{printf $4}')

echo "FAUCET_ADDRESS: ${FAUCET_ADDRESS}"
echo "FAUCET_PRIVATE_KEY: ${FAUCET_PRIVATE_KEY}"


# Start dashmate

echo "Starting dashmate"

dashmate group:start --verbose --wait-for-readiness

# Export variables

echo "::set-output name=current-version::$CURRENT_VERSION"
echo "::set-output name=faucet-address::$FAUCET_ADDRESS"
echo "::set-output name=faucet-private-key::$FAUCET_PRIVATE_KEY"
echo "::set-output name=dpns-top-level-identity-private-key::$DPNS_TOP_LEVEL_IDENTITY_PRIVATE_KEY"
echo "::set-output name=dpns-top-level-identity-id::$DPNS_TOP_LEVEL_IDENTITY_ID"
echo "::set-output name=dpns-contract-id::$DPNS_CONTRACT_ID"
echo "::set-output name=dpns-contract-block-height::$DPNS_CONTRACT_BLOCK_HEIGHT"
