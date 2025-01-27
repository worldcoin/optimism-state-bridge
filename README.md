# world-id-state-bridge

![spec](docs/state-bridge.svg)

## Description

State bridge between the WorldID Ethereum mainnet deployment and WorldID supported networks. The [spec](./docs/spec.md)
can be found in `docs/spec.md`.

## Deployments

The addresses of the contract deployments for production and staging can be found in
[`docs/deployments.md`](./docs/deployments.md#production).

## Supported networks

Currently, the supported networks are Polygon PoS (for backwards compatibility), Optimism and Base. The next iteration
of the bridge will most-likely be based on storage proofs and will support most EVM networks off the get-go, with other
networks pending storage proof verifier and Semaphore verifier implementations and deployments.

### Future integrations

If you want to support World ID on your network, please reach out to us by opening a GitHub issue. To support World ID
the current requirements are:

- have a native L1<>L2 bridge with Ethereum mainnet and Ethereum Goerli/Sepolia (for testnet integration tests)
- your network needs to have an EVM execution environment (like Optimism, Arbitrum, Scroll, Polygon zkEVM, zkSync Era,
  etc)

If your network meets these requirements, please reach out to us and we will work with you to integrate World ID. In the
mid-term future we plan on supporting storage proof solutions like [Axiom](https://axiom.xyz/) and
[Herodotus](https://herodotus.dev/) to bridge World ID state to other networks more seamlessly and with better UX and
for cheaper costs. Currently each bridge incurs the cost of each cross-chain message sent by calling the
`propagateRoot()` function. Subsidizing these costs on your end would make the integration process very simple.

If your network is not EVM-compatible/equivalent, a new implementation of the World ID contracts will need to be done
for your execution environment. Requirements are:

- Have a way to implement the `SemaphoreVerifier` and `semaphore-mtb` circuits verifier contracts which verify `Groth16`
  proofs over the `BN254` curve.
- Have the capabilities to support all cryptographic primitives that will be implemented in future versions of World ID
  as time goes on.
- Support the primitives needed to verify Axiom or Herodotus storage proofs.

For L1 to L1 bridges, there are solutions like [Succinct](https://succinct.xyz/)'s
[Telepathy](https://www.telepathy.xyz/) which have weaker security guarantees than storage proofs or native L1<>L2
bridges, but possibly allow for a World ID integration, provided that the requirements above are met.

### Build your own state bridge

#### Intro

The point of the state bridge contracts in `world-id-state-bridge` is to have two contracts, one deployed on Ethereum
mainnet and the other one on a target L2. The mainnet contract (e.g. `OpStateBridge`) has a public function which will
fetch the latest root of the World ID merkle tree using the
[`WorldIDIdentityManagerImplV1`](https://github.com/worldcoin/world-id-contracts/blob/main/src/WorldIDIdentityManagerImplV1.sol)
method named
[`latestRoot()`](https://github.com/worldcoin/world-id-contracts/blob/42c26ecbd82fba56983addee6485d5b617960a2a/src/WorldIDIdentityManagerImplV1.sol#L433-L438)
and then will use the native L1<>L2 messaging layer to send a message to the target L2 contract (e.g. `OpWorldID`). The
messaging layer of the L2 will forward the message to the target contract by calling the corresponding method on the L2
contract with the specified payload from the L1.

> [!NOTE] The current implementation of WorldID will only work for EVM-compatible networks as mentioned in the
> [Supported networks](#supported-networks) and [Future integrations](#future-integrations) sections. If you are an
> EVM-compatible rollup you also need to support the pairing cryptography and keccak256 precompiles.

The root of the World ID Identity Manager tree is the only public state that you need to send to the L2 in order to
verify Semaphore proofs (proofs of inclusion in the World ID merkle tree). As long as you have the root and a World ID
implementation on your network, you can deploy World ID on it.

#### Requirements

- service to sync the World ID merkle tree (currently only done by
  [`signup-sequencer`](https://github.com/worldcoin/signup-sequencer))
- EVM support on the L2 (pairing cryptography and keccak256 precompile support needed)
  - or a custom implementation of World ID for your execution environment (see
    [Future integrations](#future-integrations))
- native L1<>L2 data messaging layer (e.g. Optimism cross domain messenger, Arbitrum, etc)
- relayer service that periodically calls `propagateRoot()` as a cron job (e.g.
  [`state-bridge-relay`](https://github.com/worldcoin/state-bridge-relay))
- deployment scripts
- audits (World ID contracts, both `world-id-contracts` and `world-id-state-bridge` are audited by Nethermind
  ([1](https://github.com/NethermindEth/PublicAuditReports/blob/main/NM0131-FINAL_WORLDCOIN_STATE_BRIDGE_CONTRACTS_UPGRADE.pdf),
  [2](https://github.com/NethermindEth/PublicAuditReports/blob/main/NM0122-FINAL_WORLDCOIN.pdf)))

#### Specification

If you want to build your own state bridge, you can use the `OpStateBridge` contract as a template. The contract has two
main methods, namely
[`propagateRoot()`](https://github.com/worldcoin/world-id-state-bridge/blob/main/src/OpStateBridge.sol#L126) (fetches
the latest root from the
[Orb/Phone World ID IdentityManager contract](https://docs.worldcoin.org/reference/address-book) and propagates it to
the target L2 contract using the native L1->L2 messaging layer) and
[`setRootHistoryExpiry()`](https://github.com/worldcoin/world-id-state-bridge/blob/main/src/OpStateBridge.sol#L170)
(sets how long you want a propagated root to be valid for inclusion proofs) which you will need to implement. Most
native bridges will have a messenger/relayer contract and a generic interface you can use to call a function on a target
contract on the L2 with your desired calldata (which is the message). Another requirement for this system to work is to
only allow the contract on L1 to be able to call this function on the L2, otherwise anyone would be able to insert
arbitrary merkle tree roots into the L2 contract. On the `OpWorldID` contract we used a contract named
[`CrossDomainOwnable3`](https://github.com/ethereum-optimism/optimism/blob/develop/packages/contracts-bedrock/src/L2/CrossDomainOwnable3.sol)
which implements this functionality (checks that L1 sender is a given sender).

> [!NOTE] If you want to support World ID on an OP-stack network it is very easy as we have already implemented it for
> Optimism, the only change you need to make is within the deploy scripts where you need to set the
> [crossDomainMessengerAddress](https://github.com/worldcoin/world-id-state-bridge/blob/main/src/script/deploy/op-stack/optimism/DeployOptimismStateBridgeGoerli.s.sol#L32)
> to the your own network's cross domain messenger address on Ethereum L1 (whether mainnet or testnet).

## Documentation

Run `make doc` to build and deploy a simple documentation webpage on [localhost:3000](https://localhost:3000). Uses
[`forge doc`](https://book.getfoundry.sh/reference/forge/forge-doc#forge-doc) under the hood and sources information
from the `world-id-state-bridge` contracts [NatSpec](https://docs.soliditylang.org/en/latest/natspec-format.html)
documentation.

## Usage

### Install Dependencies

```sh
make install
```

### Build

Build the contracts:

```sh
make build
```

### Clean

Delete the build artifacts and cache directories:

```sh
make clean
```

### Coverage

Get a test coverage report:

```sh
make coverage
```

### Format

Format the contracts with `forge fmt` and the rest of the files (.js, .md) with Prettier:

```sh
make format
```

### Gas Usage

Get a gas report:

```sh
make snapshot
```

```sh
make bench
```

### Lint

Lint the contracts:

```sh
make lint
```

### Test

Run the tests:

```sh
make test
```

### Deploy

Deploy the WorldID state bridge and all its components to Ethereum mainnet using the CLI tool. For a more detailed
description of the deployment process and production and staging (testnet) contract addresses, see
[deployments.md](./docs/deployments.md) .

Integration with full system:

1. Deploy [`world-id-contracts`](https://github.com/worldcoin/world-id-contracts)
2. Get deployment address for `WorldIDIdentityManager`
3. (optional) you can also use the `WorldIDIdentityManager` address that can be found in
   [`docs/deployments.md`](./docs/deployments.md) to bridge existing roots.
4. Deploy [`world-id-state-bridge`](https://github.com/worldcoin/world-id-state-bridge) by running `make deploy-testnet`
   (requires 2.)
5. Start inserting identities into the
   [`WorldIDIdentityManager`](https://github.com/worldcoin/world-id-contracts/blob/main/src/WorldIDIdentityManagerImplV1.sol)
6. Propagate roots from each StateBridge contract (`OpStateBridge` on Optimism and Base and `PolygonStateBridge`) to
   their bridged World ID counterparts (`OpWorldID` on Base and Optimism and `PolygonWorldID`) by individually calling
   `propagateRoot()` on each bridge contract using
   [`state-bridge-relay`](https://github.com/worldcoin/state-bridge-relay) or any other method of calling the public
   `propagateRoot()` functions on the respective state bridges. You can monitor `PolygonWorldID` and `OpWorldID`
   (Optimism/Base) for root updates either using a block explorer or some other monitoring service (Tenderly,
   OpenZeppelin Sentinel, DataDog, ...).
7. Try and create a proof and call `verifyProof` on `OpWorldID` (Optimism/Base) or `PolygonWorldID` to check whether
   everything works.

**Note:** Remember to call all functions that change state on these contracts via the owner address, which is the
deployer address by default.

#### Testnet

Deploy the WorldID state bridge and all its components to the Goerli testnet.

Integration with full system:

1. Deploy [`world-id-contracts`](https://github.com/worldcoin/world-id-contracts)
2. Get deployment address for `WorldIDIdentityManager`
3. (optional) you can also use the `WorldIDIdentityManager` address that can be found in
   [`docs/deployments.md`](./docs/deployments.md) to bridge existing roots.
4. Deploy [`world-id-state-bridge`](https://github.com/worldcoin/world-id-state-bridge) by running `make deploy-testnet`
   (requires 2.)
5. Start inserting identities into the
   [`WorldIDIdentityManager`](https://github.com/worldcoin/world-id-contracts/blob/main/src/WorldIDIdentityManagerImplV1.sol)
6. Propagate roots from each StateBridge contract (`OpStateBridge` on Optimism and Base and `PolygonStateBridge`) to
   their bridged World ID counterparts (`OpWorldID` on Base and Optimism and `PolygonWorldID`) by individually calling
   `propagateRoot()` on each bridge contract using
   [`state-bridge-relay`](https://github.com/worldcoin/state-bridge-relay) or any other method of calling the public
   `propagateRoot()` functions on the respective state bridges. You can monitor `PolygonWorldID` and `OpWorldID`
   (Optimism/Base) for root updates either using a block explorer or some other monitoring service (Tenderly,
   OpenZeppelin Sentinel, DataDog, ...).
7. Try and create a proof and call `verifyProof` on `OpWorldID` (Optimism/Base) or `PolygonWorldID` to check whether
   everything works.

**Note:** Remember to call all functions that change state on these contracts via the owner address, which is the
deployer address by default.

#### Mock

Deploy the WorldID state bridge and a mock WorldID identity manager to the Goerli testnet for integration tests.

```bash
# to do a mock of WorlIDIdentityManager and test bridge contracts on Goerli
make mock
```

#### Local Mock

For local mock tests use localhost:8545 as the RPC URL (or just hit enter to use it by default) and use any non-empty
string as the Etherscan API key (or just hit enter to use a placeholder by default).

Run a local anvil instance to deploy the contracts locally:

```bash
anvil --mnemonic <MNEMONIC> --network goerli --deploy
```

```bash
# meant for local testing, deploys mock contracts to localhost
make local-mock
```

## Credits

This repo uses Paul Razvan Berg's [foundry template](https://github.com/paulrberg/foundry-template/): A Foundry-based
template for developing Solidity smart contracts, with sensible defaults.
