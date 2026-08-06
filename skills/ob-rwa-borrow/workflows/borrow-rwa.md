# Workflow: borrow USDC against a tokenized RWA on Onchain Bridges

Goal: open a loan against an RWA the wallet holds, on a testnet OB supports (Sepolia or Amoy).
Every on-chain action is signed by the MetaMask Agent Wallet. OB only reads state and returns
unsigned calldata. Confirm with the user before each signed step.

Endpoint base: `https://demo.onchainbridges.com/api/agent` (POST, JSON, no auth). Full contract in
`references/endpoint.md`.

## Step 1 - get the wallet address

```
mm wallet address
```

Use that address (call it `$ADDR`) for every OB call below.

## Step 2 - compliance check FIRST (never skip)

```
curl -sS -X POST https://demo.onchainbridges.com/api/agent \
  -H 'content-type: application/json' \
  -d '{"tool":"checkCompliance","payload":{"address":"'"$ADDR"'"}}'
```

Read `perChain[]` (and `perAsset[]` if present). Each entry has `eligible` (true/false) per
(chain, asset).

- If the wallet is **not eligible** on the chain/asset the user wants: tell them plainly they need to
  get verified at **https://kyc.onchainbridges.com**, that one verification is portable across OB's
  CCIP EVM chains, and STOP. Do not attempt a borrow - it would revert on-chain.
- If **eligible**: continue.

Do not paraphrase eligibility loosely: report exactly what the response says. Allowlist-only assets
(gold/RE in this phase) are "allowlisted", not "KYC-gated" - see `references/compliance.md`.

## Step 3 - (optional) compare loans

If the user hasn't named an asset/chain, help them pick:

```
curl -sS -X POST https://demo.onchainbridges.com/api/agent \
  -H 'content-type: application/json' \
  -d '{"tool":"compareLoans","payload":{"goal":"max-borrow","address":"'"$ADDR"'"}}'
```

`goal` is `cheapest` | `max-borrow` | `balanced`. Passing `address` makes OB rank assets the wallet
actually holds above ones it does not (a row it cannot borrow is demoted, never shown as "best").
Read `winner` for the recommendation; `ranked[]` for all options. Each row carries `assetId`,
`chainName`, `maxLtv`, `borrowApr`, `maxBorrowUsdc`. Present them; let the user choose.

## Step 4 - fetch the borrow calldata from OB

Ask OB to prepare the loan. `asset` is the RWA ticker (`MBT` | `AVR` | `TGLP` | ...), `targetChain`
is the chain key (`sepolia` | `amoy`), `collateralAmount` is the number of RWA tokens to deposit:

```
curl -sS -X POST https://demo.onchainbridges.com/api/agent \
  -H 'content-type: application/json' \
  -d '{"tool":"bridgeAndBorrow","payload":{"targetChain":"amoy","asset":"AVR","collateralAmount":2,"identity":{"address":"'"$ADDR"'"}}}'
```

Two possible responses:

- **`userSignTxs`** (an array of 2) = ready to sign. Each element is `{ to, data, chainId, label }`.
  OB has already pre-checked compliance, collateral balance, and gas. Go to Step 5.
- **`refused`** = OB cannot prepare it (e.g. wallet holds no collateral, or not allowlisted). Relay
  `userFacingText` verbatim and STOP. Never fall back to a hand-built transaction.

## Step 5 - sign the two transactions, in order, with confirmation

`userSignTxs[0]` is the **approve**; `userSignTxs[1]` is the **borrow**. Send them one at a time,
IN ORDER (the borrow will fail if the approve isn't mined first). For each:

1. Decode it so the user sees what it does:
   ```
   mm decode --payload <data>
   ```
2. Show OB's `label` (e.g. "1. Approve 2 AVR for Atlas Capital vault") + the decoded intent, and get
   the user's OK. For the approve, confirm the amount is exactly the collateral and the spender is the
   vault address from OB - flag it if anything is larger or different.
3. Submit it (value is 0 for both approve and borrow):
   ```
   mm wallet send-transaction --chain-id <chainId> --payload '{"to":"<to>","value":"0x0","data":"<data>"}' --wait
   ```
4. Only after the approve confirms, send the borrow the same way.

## Step 6 - confirm

After the borrow confirms, report the loan is open: the amount borrowed (`borrowedUsdc` if OB
returned it, else the borrow `label`), the asset and chain, and the transaction hashes. Remind the
user this is testnet.

## Guardrails specific to this workflow

- OB is the ONLY source of `to`/`data`. If you did not get it from a `userSignTxs` response, do not
  send it.
- Never approve more than the collateral amount. OB's approve is exact-amount by design; anything
  unlimited is a red flag, not an OB transaction.
- If compliance said not-eligible, there is no borrow to attempt - route to KYC and stop.
- Testnet only today. Do not describe testnet loans as real funds.
