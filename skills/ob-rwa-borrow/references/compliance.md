# Reference: the Onchain Bridges compliance model

OB is regulated-RWA infrastructure. Borrowing is gated on-chain - a wallet must be admitted before
the contracts will let it open a loan. This is the core difference from permissionless lending, and
it is enforced by the OB contracts, not by this skill or by the MetaMask Agent Wallet.

## Two admission recipes

- **Composed (MBT, tokenized real estate on the credentialed chains):** the wallet must be BOTH
  allowlisted AND hold a valid KYC credential. On Sepolia / Amoy / Plume this is `allowlist AND
  credential`.
- **Allowlist-only (AVR gold, TGLP industrial RE, and other catalog assets in this phase):** the
  wallet must be on that chain's shared master allowlist. There is NO KYC credential requirement on
  these yet. Report their eligibility as "allowlisted" - do not describe them as "KYC-gated".

`checkCompliance` returns a `gate` field per asset (`"composed"` vs `"allowlist"`). Report exactly
what it says per asset; never generalize one asset's verdict to another.

## How a wallet becomes eligible

One KYC verification at **https://kyc.onchainbridges.com** issues a portable credential that is valid
across OB's CCIP EVM chains - verify once, borrow across Sepolia, Amoy, Plume. (Sonic enforces the
same eligibility through the token's built-in allowlist rather than the portable credential.)

If `checkCompliance` returns `eligible:false` for the chain/asset the user wants:
1. Tell them plainly they are not yet admitted on OB for that asset.
2. Route them to https://kyc.onchainbridges.com to get verified.
3. Note that one verification is portable across the CCIP EVM chains.
4. STOP. Do not attempt the borrow - it will revert on-chain, wasting gas.

## Why this fails safe

If a borrow is attempted by a non-admitted wallet, the OB vault reverts. The MetaMask Agent Wallet's
transaction simulation previews that revert before signing, so no funds are lost either way. Running
`checkCompliance` first just turns a cryptic simulated revert into a clear "get verified" message.

## What this skill does NOT do

It does not perform KYC, issue credentials, or add wallets to the allowlist. Those are OB-side
actions the user completes through the KYC flow. This skill only checks status and, for admitted
wallets, fetches and submits the borrow calldata.
