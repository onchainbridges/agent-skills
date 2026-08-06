# Reference: chains and assets

## Chains (this phase: testnet)

OB's lending vaults are live on testnets today. This skill targets the two that the MetaMask Agent
Wallet also supports, so an agent can drive them directly:

| Chain            | chainId  | OB chain key | MetaMask Agent Wallet |
|------------------|----------|--------------|-----------------------|
| Ethereum Sepolia | 11155111 | `sepolia`    | supported             |
| Polygon Amoy     | 80002    | `amoy`       | supported             |

OB is also live on Sonic Testnet and Plume Testnet, but use Sepolia/Amoy for MetaMask-agent flows
since those are the ones both sides support cleanly.

**Mainnet is not live for lending yet.** OB has Base integration on the roadmap (Base mainnet, 8453,
is supported by the MetaMask Agent Wallet). When OB's mainnet RWA vaults deploy, this skill extends
to them with no format change - only the chain keys and addresses differ. Until then, treat all loans
here as testnet with no real value.

## Assets (RWA tickers)

The authoritative, current list comes from the live catalog (call `compareLoans` with no `asset` to
enumerate what is borrowable). As of this skill version:

| Ticker | Asset                          | Type                    | Borrowable on | Gate         |
|--------|--------------------------------|-------------------------|---------------|--------------|
| MBT    | Miami Beach Tower              | Office real estate      | Sepolia, Amoy, Sonic, Plume | composed (allowlist + KYC) |
| AVR    | Aurum Vault Reserve            | Vaulted gold            | Amoy          | allowlist-only |
| TGLP   | Thames Gateway Logistics Park  | Industrial real estate  | Amoy          | allowlist-only |

Other tickers may be listed in the catalog but not yet borrowable (no lending vault). `compareLoans`
and `bridgeAndBorrow` are the source of truth: a listed-but-not-borrowable asset returns a `no_vault`
refusal, which you relay rather than work around.

Do NOT hardcode vault or token addresses in this skill. Every `to`/`data` used in a transaction
comes verbatim from a `bridgeAndBorrow` `userSignTxs` response, so addresses stay correct even as the
catalog changes.
