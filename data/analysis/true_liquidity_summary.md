# True Liquidity Summary

This summary compares the old transfer-based proxy with the new historical DEX
liquidity feature.

## New feature

- File: `classifier/historical_dex_liquidity.py`
- Output:
  - `classifier/data/analysis/ethereum_true_liquidity.csv`
  - `classifier/data/analysis/bsc_true_liquidity.csv`

Definition:

- For each ERC-20 contract at a target block, sum USD liquidity across direct
  pools against major quote assets on major v2/v3 DEX factories.
- Historical pricing uses the target block itself.

## Benchmark recall

All SCONE positives:

- Ethereum:
  - Old proxy `verified & erc20 & traded & total_transfer_in_usd >= 1k`
    - `18 / 174 = 10.3%`
  - New feature `verified & erc20 & traded & historical_dex_liquidity >= 1k`
    - `26 / 174 = 14.9%`
- BSC:
  - Old proxy `verified & erc20 & traded & total_transfer_in_usd >= 1k`
    - `42 / 216 = 19.4%`
  - New feature `verified & erc20 & traded & historical_dex_liquidity >= 1k`
    - `86 / 216 = 39.8%`

ERC-20 positives only:

- Ethereum:
  - Old proxy `>= 1k`
    - `18 / 51 = 35.3%`
  - New historical DEX liquidity `>= 1k`
    - `26 / 51 = 51.0%`
- BSC:
  - Old proxy `>= 1k`
    - `42 / 121 = 34.7%`
  - New historical DEX liquidity `>= 1k`
    - `86 / 121 = 71.1%`

Additional thresholds:

- Ethereum ERC-20 positives:
  - historical DEX liquidity `>= 10k`: `23 / 51 = 45.1%`
  - at least one discovered pool: `28 / 51 = 54.9%`
- BSC ERC-20 positives:
  - historical DEX liquidity `>= 10k`: `78 / 121 = 64.5%`
  - at least one discovered pool: `93 / 121 = 76.9%`

## Interpretation

- Replacing transfer inflow with true historical DEX liquidity materially
  improves the token-centric branch on both chains.
- The improvement is especially strong on BSC, where the new feature roughly
  doubles all-positive recall versus the old proxy.
- The token-centric branch remains much narrower than the best activity-based
  filters for overall SCONE recall.
