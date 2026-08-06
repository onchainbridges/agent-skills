# Reference: the Onchain Bridges agent endpoint

Single endpoint, POST JSON, no auth, HTTPS:

```
POST https://demo.onchainbridges.com/api/agent
Content-Type: application/json
Body: {"tool":"<toolName>","payload":{ ... }}
```

OB only READS chain state and RETURNS data or unsigned calldata. It never signs, never holds keys,
never moves funds. All signing is done by the MetaMask Agent Wallet.

Three tools are used by this skill.

---

## checkCompliance (read)

Is a wallet allowed to borrow on OB, per chain and per asset?

Request:
```json
{"tool":"checkCompliance","payload":{"address":"0x..."}}
```

Response (shape):
```json
{
  "address": "0x...",
  "admitted": true,
  "perChain": [
    {"chainKey":"sepolia","chainId":11155111,"chainName":"Ethereum Sepolia","allowlisted":true,"credentialed":true,"eligible":true,"read":"live"},
    {"chainKey":"amoy","chainId":80002,"chainName":"Polygon Amoy","allowlisted":true,"credentialed":true,"eligible":true,"read":"live"}
  ],
  "perAsset": [
    {"assetId":"MBT","gate":"composed","chains":[{"chainName":"Polygon Amoy","eligible":true}]},
    {"assetId":"AVR","gate":"allowlist","chains":[{"chainName":"Polygon Amoy","eligible":true}]}
  ]
}
```

Gate the borrow on `eligible` for the (chain, asset) the user wants. `gate` is `"composed"`
(allowlist AND KYC credential) or `"allowlist"` (allowlist only). `read:"live"` means it was read
on-chain; anything else means the read was unavailable - do not treat unavailable as eligible.

---

## compareLoans (read)

Rank available loans. Pass `address` so OB demotes assets the wallet does not hold.

Request:
```json
{"tool":"compareLoans","payload":{"goal":"max-borrow","address":"0x...","asset":"AVR"}}
```
- `goal`: `"cheapest"` | `"max-borrow"` | `"balanced"`.
- `asset` (optional): scope to one RWA; omit to rank across all.
- `address` (optional but recommended): rank held assets above unheld ones.

Response carries `winner` and `ranked[]`; each row has `assetId`, `assetName`, `chainName`,
`maxLtv`, `borrowApr`, `availableLiquidity`, `maxBorrowUsdc`, `heldByWallet`, and a stable `id`.
`rankedBy` names the axis that actually sorted.

---

## bridgeAndBorrow (returns unsigned calldata OR an honest refusal)

Prepare a loan. OB pre-checks compliance, collateral balance, and gas, then returns the two
transactions to sign.

Request:
```json
{"tool":"bridgeAndBorrow","payload":{"targetChain":"amoy","asset":"AVR","collateralAmount":2,"identity":{"address":"0x..."}}}
```

Success response:
```json
{
  "userSignTxs": [
    {"to":"0x<collateralToken>","data":"0x095ea7b3...","chainId":80002,"label":"1. Approve 2 AVR for Atlas Capital vault"},
    {"to":"0x<vault>","data":"0xc5ebeaec...","chainId":80002,"label":"2. Open <n> USDC loan on Atlas Capital"}
  ],
  "summary": "Sign 2 transactions to open a <n> USDC loan on Atlas Capital (Polygon Amoy).",
  "simulated": false
}
```

- `userSignTxs[0]` is the ERC-20 `approve` of exactly `collateralAmount` to the vault.
- `userSignTxs[1]` is the vault `borrow`.
- Both take `value` = `"0x0"`.
- Feed each `{to, data}` + its `chainId` to `mm wallet send-transaction`.

Refusal response (do NOT sign anything; relay the message):
```json
{"refused":true,"kind":"tool_not_ready","userFacingText":"Your wallet holds 0.00 AVR on Polygon Amoy, needs at least 2 AVR ...","simulated":false}
```
Refusal `kind` values you may see: `not_allowlisted`, `no_vault`, `unknown_asset`, `tool_not_ready`.
Always relay `userFacingText` and stop.

---

## Honesty invariant

`simulated` is always `false` on real responses. OB never fabricates a transaction or a result. If a
response ever carries `simulated:true` or a transaction hash OB did not get from a signed on-chain
tx, treat it as a bug and stop - but by design that never happens.
