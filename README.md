# Onchain Bridges - agent skills

[![secret-scan](https://github.com/onchainbridges/agent-skills/actions/workflows/secret-scan.yml/badge.svg)](https://github.com/onchainbridges/agent-skills/actions/workflows/secret-scan.yml)

Skills that let AI agents interact with [Onchain Bridges](https://onchainbridges.com), a
compliance-gated, cross-chain protocol for borrowing stablecoins against tokenized real-world assets
(real estate, gold, and more).

## `ob-rwa-borrow`

Borrow USDC against a tokenized RWA you hold, through the **MetaMask Agent Wallet**. The skill checks
your wallet's KYC/allowlist status on Onchain Bridges, fetches the exact `approve` + `borrow` calldata
from OB's public agent endpoint, and submits it with `mm wallet send-transaction` - under your
wallet's own guardrails (simulation, threat-scan, outflow limits, approval).

Onchain Bridges never holds your keys, never signs, and never moves funds. It only reads on-chain
state and returns unsigned transaction calldata; your MetaMask Agent Wallet signs everything.

**Status:** testnet - live on Ethereum Sepolia and Polygon Amoy (both supported by the MetaMask Agent
Wallet). Mainnet (Base) follows when OB's mainnet vaults are live.

### Install (into a MetaMask Agent Wallet setup)

```
npx skills add onchainbridges/agent-skills
```

When prompted, install `ob-rwa-borrow`. This skill assumes the `metamask-agent-wallet` skill and the
`mm` CLI are already installed and authenticated.

### What it does

1. `mm wallet address` - identify the wallet.
2. Check compliance on Onchain Bridges (`checkCompliance`). If the wallet is not admitted, route to
   https://kyc.onchainbridges.com and stop.
3. Optionally compare loans across assets/chains, ranked by what the wallet actually holds.
4. Fetch the two unsigned transactions (`approve` then `borrow`) from OB.
5. Decode, confirm, and submit each with `mm wallet send-transaction`, in order.

Full flow: [`skills/ob-rwa-borrow/workflows/borrow-rwa.md`](skills/ob-rwa-borrow/workflows/borrow-rwa.md).
Endpoint contract: [`skills/ob-rwa-borrow/references/endpoint.md`](skills/ob-rwa-borrow/references/endpoint.md).

### Design notes

- **Thin by construction.** OB's `/api/agent` endpoint already returns the exact `{to, data, chainId}`
  transaction shape the MetaMask Agent Wallet consumes. This skill is a router, not a re-implementation.
- **Compliance is on-chain.** A non-admitted wallet's borrow reverts at the OB contract; the wallet's
  simulation catches it. The compliance pre-check just turns that into a clear message.
- **No hardcoded addresses.** Vault and token addresses come from OB responses at call time, so the
  skill stays correct as the asset catalog evolves.

## License

MIT
