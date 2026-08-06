---
name: ob-rwa-borrow
description: Borrow USDC against tokenized real-world assets (real estate, gold) on Onchain Bridges, a compliance-gated cross-chain RWA lending protocol. The agent checks the wallet's KYC/allowlist status, fetches the exact approve + borrow calldata from Onchain Bridges, and submits it with the MetaMask Agent Wallet. Testnet (Sepolia, Polygon Amoy) today.
license: MIT
metadata:
  author: Onchain Bridges
  version: 0.1.0
  cliVersion: ">=0.x"
---

# Borrow against tokenized RWA on Onchain Bridges

Onchain Bridges (OB) is a compliance-gated, cross-chain protocol for borrowing stablecoins against
tokenized real-world assets. This skill lets your MetaMask Agent Wallet open a loan against an RWA
you hold - for example borrow USDC against tokenized office real estate (MBT), vaulted gold (AVR),
or industrial real estate (TGLP).

**OB does NOT hold your keys and never signs for you.** It only READS on-chain state and RETURNS
unsigned transaction calldata. Every transaction is signed by your MetaMask Agent Wallet, under its
own guardrails (simulation, threat-scan, outflow limits, approval). This skill is a thin bridge
between OB's calldata API and `mm wallet send-transaction`.

**Status: testnet.** Live on Ethereum Sepolia (11155111) and Polygon Amoy (80002), both supported
by the MetaMask Agent Wallet. Mainnet (Base) is on OB's roadmap; this skill will extend to it when
the mainnet vaults are live. Do not present testnet loans as real value.

## How OB works (two gates, both must pass)

1. **Compliance gate (OB-side, on-chain).** OB is regulated-RWA infrastructure: a wallet must be
   allowlisted (and for some assets KYC-credentialed) before it can borrow. This is enforced by the
   OB contracts, not by this skill - an un-admitted wallet's borrow transaction REVERTS on-chain,
   which the MetaMask Agent Wallet's simulation will catch. Always run the compliance check FIRST so
   the user gets a clean "get verified" message instead of a failed simulation.
2. **Your wallet's guardrails (MetaMask-side).** Outflow limits, 2FA, threat-scan, simulation. These
   are yours and stay in force. This skill never bypasses them.

## Command routing

| The user wants to...                          | Do this                                                        |
|-----------------------------------------------|----------------------------------------------------------------|
| Check if their wallet can borrow on OB        | Compliance check -> `references/endpoint.md` (checkCompliance)  |
| See the best loan / compare assets and rates  | Compare loans -> `references/endpoint.md` (compareLoans)        |
| Actually open a loan against an RWA           | Run `workflows/borrow-rwa.md` end to end                       |
| Understand which chains / assets are supported| `references/chains.md`                                          |
| Understand the KYC / allowlist model          | `references/compliance.md`                                      |

## The core rule for THIS skill's transactions

OB borrows are exactly **two** transactions, in order, on the SAME chain:

1. **`approve`** - grant the OB lending vault an allowance of EXACTLY the collateral amount you are
   depositing (not unlimited). Your wallet's guardrails will (correctly) flag any `approve`; this one
   is expected and legitimate. Surface OB's own human-readable `label` for it (e.g. "Approve 2 MBT
   for Atlas Capital vault") and the decoded amount, and confirm it approves the exact collateral
   token to the exact vault address OB returned - nothing more.
2. **`borrow`** - deposit the approved collateral into the vault and receive the USDC loan.

Never invent addresses or amounts. The `to`, `data`, and `chainId` for BOTH transactions come
verbatim from OB's `bridgeAndBorrow` response (`userSignTxs`). If OB returns `refused` instead of
`userSignTxs`, relay its `userFacingText` and stop - do not attempt a raw transaction.

See `workflows/borrow-rwa.md` for the exact step-by-step.
