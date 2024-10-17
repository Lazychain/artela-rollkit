#!/bin/bash

KEY="validator"

CHAINID="artroll_11820-1"
MONIKER="localtestnet"
KEYRING="test"
KEYALGO="eth_secp256k1"
LOGLEVEL="debug"
# trace evm
TRACE="--trace"
# TRACE=""

# Lazy extra configuration
NODE="0.0.0.0"
TOKEN_DENOM="aart"
MIN_GAS="0"
MAX_GAS="20000000"

export PATH=./:./build:$PATH

# Lazy Messages color
RED='\033[0;31m'
NC='\033[0m' # No Color

# validate dependencies are installed
command -v jq >/dev/null 2>&1 || {
    echo >&2 "jq not installed. More info: https://stedolan.github.io/jq/download/"
    exit 1
}

# remove existing daemon and client
workdir="$HOME/.artroll"
echo workdir
echo -e "Saving all configuration on ${RED}[$workdir]${NC}!!!"
if [ -d "$workdir" ]; then
  read -p "Are you sure you want to delete the folder '$workdir' ? (y/n): " confirm

  if [ "$confirm" == "y" ]; then
    rm -rf "$workdir"
    echo "The folder has been deleted."
  else
    echo "Operation canceled."
    exit 1
  fi
fi

artrolld config set client chain-id $CHAINID
artrolld config set client keyring-backend $KEYRING

# if keys exists it should be deleted
echo -e "---------${RED}"
echo -e "Setting validator"
artrolld keys add validator --keyring-backend $KEYRING --algo $KEYALGO
echo -e "---------${NC}"

# Set moniker and chain-id for artela (Moniker can be anything, chain-id must be an integer). We hide the output.
artrolld init $MONIKER --chain-id $CHAINID > out.log 2> /dev/null

# Change parameter token denominations to TOKEN_DENOM
cat $workdir/config/genesis.json | jq -r '.app_state["staking"]["params"]["bond_denom"]="'$TOKEN_DENOM'"' >$workdir/config/tmp_genesis.json && mv $workdir/config/tmp_genesis.json $workdir/config/genesis.json
cat $workdir/config/genesis.json | jq -r '.app_state["crisis"]["constant_fee"]["denom"]="'$TOKEN_DENOM'"' >$workdir/config/tmp_genesis.json && mv $workdir/config/tmp_genesis.json $workdir/config/genesis.json
cat $workdir/config/genesis.json | jq -r '.app_state["gov"]["deposit_params"]["min_deposit"][0]["denom"]="'$TOKEN_DENOM'"' >$workdir/config/tmp_genesis.json && mv $workdir/config/tmp_genesis.json $workdir/config/genesis.json
cat $workdir/config/genesis.json | jq -r '.app_state["gov"]["params"]["min_deposit"][0]["denom"]="'$TOKEN_DENOM'"' >$workdir/config/tmp_genesis.json && mv $workdir/config/tmp_genesis.json $workdir/config/genesis.json
cat $workdir/config/genesis.json | jq -r '.app_state["gov"]["params"]["expedited_min_deposit"][0]["denom"]="'$TOKEN_DENOM'"' >$workdir/config/tmp_genesis.json && mv $workdir/config/tmp_genesis.json $workdir/config/genesis.json
cat $workdir/config/genesis.json | jq -r '.app_state["mint"]["params"]["mint_denom"]="'$TOKEN_DENOM'"' >$workdir/config/tmp_genesis.json && mv $workdir/config/tmp_genesis.json $workdir/config/genesis.json

# lazy extra
# cat $workdir/config/genesis.json | jq -r '.app_state["evm"]["params"]["evm_denom"]="'$TOKEN_DENOM'"' >$workdir/config/tmp_genesis.json && mv $workdir/config/tmp_genesis.json $workdir/config/genesis.json

# Set gas limit in genesis
cat $workdir/config/genesis.json | jq -r '.consensus_params["block"]["max_gas"]="'$MAX_GAS'"' >$workdir/config/tmp_genesis.json && mv $workdir/config/tmp_genesis.json $workdir/config/genesis.json
cat $workdir/config/genesis.json | jq '.app_state["evm"]["params"]["extra_eips"]=[3855]' >$workdir/config/tmp_genesis.json && mv $workdir/config/tmp_genesis.json $workdir/config/genesis.json

# Enable unprotected txs
cat $workdir/config/genesis.json | jq '.app_state["evm"]["params"]["allow_unprotected_txs"]=true' >$workdir/config/tmp_genesis.json && mv $workdir/config/tmp_genesis.json $workdir/config/genesis.json

# Allocate genesis contract)
artrolld add-genesis-contract 0x000000000000000000000000000000000000AAEC $(cat genesis-contract)

# This section pertains to the account abstraction for specific cases within the Artela Aspect. The source code can be found here.
# For the moment we are not utilizing the Aspect to implement functionalities similar to session keys.
# Allocate genesis accounts (cosmos formatted addresses)
artrolld add-genesis-account validator "100000000000000000000000000$TOKEN_DENOM" --keyring-backend $KEYRING

echo "Sign genesis transaction"
artrolld gentx validator "1000000000000000000000$TOKEN_DENOM" --keyring-backend $KEYRING --chain-id $CHAINID --fees "4000000000000000$TOKEN_DENOM"

ADDRESS=$(jq -r '.address' $workdir/config/priv_validator_key.json)
PUB_KEY=$(jq -r '.pub_key' $workdir/config/priv_validator_key.json)

echo -e "Validator Address ${RED}[$ADDRESS]${NC}!!!"

jq --argjson pubKey "$PUB_KEY" '.consensus["validators"]=[{"address": "'$ADDRESS'", "pub_key": $pubKey, "power": "1000000000000000", "name": "Rollkit Sequencer"}]' $workdir/config/genesis.json > temp.json && mv temp.json $workdir/config/genesis.json

# Collect genesis tx
artrolld collect-gentxs >/dev/null 2>&1

# Run this to ensure everything worked and that the genesis file is setup correctly
artrolld validate-genesis

# disable produce empty block and enable prometheus metrics
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' 's/create_empty_blocks = true/create_empty_blocks = false/g' $workdir/config/config.toml
    sed -i '' 's/prometheus = false/prometheus = true/' $workdir/config/config.toml
    sed -i '' 's/prometheus-retention-time = 0/prometheus-retention-time = 1000000000000/g' $workdir/config/app.toml
    sed -i '' 's/enabled = false/enabled = true/g' $workdir/config/app.toml
    sed -i '' 's/127.0.0.1:8545/0.0.0.0:8545/g' $workdir/config/app.toml
    sed -i '' 's/allow-unprotected-txs = false/allow-unprotected-txs = true/g' $workdir/config/app.toml

    # set prunning options
    sed -i '' 's/pruning = "default"/pruning = "nothing"/g' $workdir/config/app.toml
    sed -i '' 's/pruning-keep-recent = "0"/pruning-keep-recent = "2"/g' $workdir/config/app.toml
    sed -i '' 's/pruning-interval = "0"/pruning-interval = "10"/g' $workdir/config/app.toml

    # set snapshot options
    # sed -i '' 's/snapshot-interval = 0/snapshot-interval = 2000/g' $workdir/config/app.toml
    sed -i '' 's/enable = false/enable = true/g' $workdir/config/app.toml
    sed -i '' 's/prometheus = false/prometheus = true/' $workdir/config/config.toml
    sed -i '' 's/prometheus-retention-time = 0/prometheus-retention-time = 1000000000000/' $workdir/config/app.toml
else
    # lazy
    # Linux / Windows
    echo "Working on [$OSTYPE] config.toml file"
    echo "Setting minimun gas price to [$MIN_GAS$TOKEN_DENOM]"
    sed -i "s/minimum-gas-prices = \"0aart\"/minimum-gas-prices = \"$MIN_GAS$TOKEN_DENOM\"/g" $workdir/config/app.toml

    echo "Disable produce empty block"
    sed -i 's/create_empty_blocks = true/create_empty_blocks = false/g' $workdir/config/config.toml
    echo "Enable prometheus metrics"
    sed -i 's/prometheus = false/prometheus = true/' $workdir/config/config.toml
    sed -i 's/prometheus-retention-time  = "0"/prometheus-retention-time = "1000000000000"/g' $workdir/config/app.toml
    sed -i 's/enabled = false/enabled = true/g' $workdir/config/app.toml
    sed -i 's/127.0.0.1:8545/0.0.0.0:8545/g' $workdir/config/app.toml
    echo "allow-unprotected-txs true"
    sed -i 's/allow-unprotected-txs = false/allow-unprotected-txs = true/g' $workdir/config/app.toml

    # set prunning options
    echo "set prunning nothing"
    sed -i 's/pruning = "default"/pruning = "nothing"/g' $workdir/config/app.toml
    # sed -i 's/pruning-keep-recent = "0"/# pruning-keep-recent = "2"/g' $workdir/config/app.toml
    # sed -i 's/pruning-interval = "0"/# pruning-interval = "10"/g' $workdir/config/app.toml

    echo "set snapshot true and prometheus"
    # sed -i 's/snapshot-interval = 0/snapshot-interval = 2000/g' $workdir/config/app.toml
    sed -i 's/enable = false/enable = true/g' $workdir/config/app.toml
    sed -i 's/prometheus = false/prometheus = true/' $workdir/config/config.toml
    sed -i 's/prometheus-retention-time = 0/prometheus-retention-time = 1000000000000/' $workdir/config/app.toml
    # sed -i 's/timeout_commit = "5s"/timeout_commit = "500ms"/' $workdir/config/config.toml
fi

if [[ $1 == "pending" ]]; then
    echo "pending mode is on, please wait for the first block committed."
    if [[ $OSTYPE == "darwin"* ]]; then
        sed -i '' 's/create_empty_blocks_interval = "0s"/create_empty_blocks_interval = "30s"/g' $workdir/config/config.toml
        sed -i '' 's/timeout_propose = "3s"/timeout_propose = "30s"/g' $workdir/config/config.toml
        sed -i '' 's/timeout_propose_delta = "500ms"/timeout_propose_delta = "5s"/g' $workdir/config/config.toml
        sed -i '' 's/timeout_prevote = "1s"/timeout_prevote = "10s"/g' $workdir/config/config.toml
        sed -i '' 's/timeout_prevote_delta = "500ms"/timeout_prevote_delta = "5s"/g' $workdir/config/config.toml
        sed -i '' 's/timeout_precommit = "1s"/timeout_precommit = "10s"/g' $workdir/config/config.toml
        sed -i '' 's/timeout_precommit_delta = "500ms"/timeout_precommit_delta = "5s"/g' $workdir/config/config.toml
        sed -i '' 's/timeout_commit = "5s"/timeout_commit = "150s"/g' $workdir/config/config.toml
        sed -i '' 's/timeout_broadcast_tx_commit = "10s"/timeout_broadcast_tx_commit = "150s"/g' $workdir/config/config.toml
    else
        sed -i 's/create_empty_blocks_interval = "0s"/create_empty_blocks_interval = "30s"/g' $workdir/config/config.toml
        sed -i 's/timeout_propose = "3s"/timeout_propose = "30s"/g' $workdir/config/config.toml
        sed -i 's/timeout_propose_delta = "500ms"/timeout_propose_delta = "5s"/g' $workdir/config/config.toml
        sed -i 's/timeout_prevote = "1s"/timeout_prevote = "10s"/g' $workdir/config/config.toml
        sed -i 's/timeout_prevote_delta = "500ms"/timeout_prevote_delta = "5s"/g' $workdir/config/config.toml
        sed -i 's/timeout_precommit = "1s"/timeout_precommit = "10s"/g' $workdir/config/config.toml
        sed -i 's/timeout_precommit_delta = "500ms"/timeout_precommit_delta = "5s"/g' $workdir/config/config.toml
        sed -i 's/timeout_commit = "5s"/timeout_commit = "150s"/g' $workdir/config/config.toml
        sed -i 's/timeout_broadcast_tx_commit = "10s"/timeout_broadcast_tx_commit = "150s"/g' $workdir/config/config.toml
    fi
fi

# TODO: find a better way to update the genesis.json file without copy-paste
cat $workdir/config/genesis.json | jq -r '.app_name="artela-rollkitd"' >$workdir/config/tmp_genesis.json && mv $workdir/config/tmp_genesis.json $workdir/config/genesis.json
# kurtosis require this
sed -i "s/localhost:/0.0.0.0:/g" $workdir/config/app.toml
sed -i "s/127.0.0.1:/0.0.0.0:/g" $workdir/config/app.toml
sed -i "s/localhost:/0.0.0.0:/g" $workdir/config/client.toml
sed -i "s/127.0.0.1:/0.0.0.0:/g" $workdir/config/client.toml
sed -i "s/localhost:/0.0.0.0:/g" $workdir/config/config.toml
sed -i "s/127.0.0.1:/0.0.0.0:/g" $workdir/config/config.toml

artrolld start --rollkit.aggregator --rollkit.da_address $DA_ADDRESS
