# ZeroGStorage 

## Compile

```shell
yarn
yarn compile
```

## Deploy contract

Firstly, create file `./deploy/localtest.py` to store created contract address. Then, run following command to deploy contracts:

```shell
npx hardhat run scripts/deploy.ts --network targetnetwork
```

Supported networks:

- localtest
- bsc
- conflux

Note, please make sure that there is enough balance for the configured account.
