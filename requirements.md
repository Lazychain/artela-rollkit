# Requirements

## Install

### Kurtosis

[kurtosis](https://docs.kurtosis.com/install)

### Ignite

```bash
curl https://get.ignite.com/cli@v28.4.0! | bash
```

### Rollkit

```golang
github.com/rollkit/rollkit v0.13.6
github.com/rollkit/go-da v0.5.0 
```

## Compile

- go version: go1.22.7

Note: version > 1.22.7 have conflicts

This generates all the binary necessary, but we dont use the generated gaia executable since rollkit-artella replaces it.

```bash
ignite chain build
```

## Generate lazy blockchain configuration

This script generate in [./lazy]

```bash
./lazy_init.sh
```

## Run locally

```bash
docker run --name local-da -tid -p 7980:7980 ghcr.io/rollkit/local-da:v0.2.1
./artrolld start --rollkit.aggregator --rollkit.da_address 'http://127.0.0.1:7980' --home ./.lazy
```

## Docker compose (localhost)

```bash
docker compose build
```
