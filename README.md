# Frontier Chain

**Frontier Chain** is a blockchain application built using Cosmos SDK and Tendermint.

---

## Setup

Initialize the blockchain with one validator node:

```bash
rm -r ~/.frontcli
rm -r ~/.frontd

make install

frontd init mynode --chain-id frontierchain1

# Update chain's main denom from 'stake' to 'front'
jq '.app_state.staking.params.bond_denom = "front"' ~/.frontd/config/genesis.json|sponge ~/.frontd/config/genesis.json
jq '.app_state.crisis.constant_fee.denom = "front"' ~/.frontd/config/genesis.json|sponge ~/.frontd/config/genesis.json
jq '.app_state.mint.params.mint_denom = "front"' ~/.frontd/config/genesis.json|sponge ~/.frontd/config/genesis.json
jq '.app_state.gov.deposit_params.min_deposit[0].denom = "front"' ~/.frontd/config/genesis.json|sponge ~/.frontd/config/genesis.json

frontcli config keyring-backend test
frontcli config chain-id frontierchain1
frontcli config output json
frontcli config indent true
frontcli config trust-node true

frontcli keys add user1
frontcli keys add user2
frontd add-genesis-account $(frontcli keys show user1 -a) 110000000front
frontd add-genesis-account $(frontcli keys show user2 -a) 5000000front

frontd gentx --name user1 --amount=10000000front --keyring-backend test

frontd collect-gentxs
```

---

## Start

Start the blockchain:

```bash
frontd start
```

---

## Configuration

The blockchain's initialization parameters are stored in `~/.frontd/config/genesis.json`.

---

## Blockchain CLI

`frontcli` is a CLI that can be used to interact with the blockchain. Let's use it to transfer some tokens:

```bash
 # example usage: frontcli tx send [from_key_or_address] [to_address] [amount] [flags]
 frontcli tx send user1 front1y0ygwej3hqc8epzmytg0hdr7ylytpnq8cnpuvq 10front --from user1
```

---

## Frontend Application

Start the frontend application on `localhost:8080`:

```bash
cd vue/
npm i && npm run serve
```

The frontend application can be used to transfer tokens between accounts.

---

## Learn more

- [Cosmos SDK documentation](https://docs.cosmos.network)
- [Cosmos Tutorials](https://tutorials.cosmos.network)
