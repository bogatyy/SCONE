# Historical DEX Liquidity Redesign

This replaces the old `total_transfer_in_usd` proxy with a block-aware,
point-in-time DEX liquidity feature that is much closer to the Anthropic paper's
"aggregate liquidity across all decentralized exchanges" filter.

## Implemented feature

For a token contract `T` at block `B`:

1. Enumerate major quote assets on the chain.
2. Query major DEX factories for direct `T/quote` pools at `B`.
3. Value each pool in USD at `B`.
4. Sum pool USD liquidity across all discovered pools.

The current implementation supports:

- Ethereum:
  - Uniswap v2
  - SushiSwap v2
  - Uniswap v3
  - Quote assets: `USDC`, `USDT`, `DAI`, `WETH`
- BSC:
  - PancakeSwap v2
  - PancakeSwap v3
  - Quote assets: `USDT`, `USDC`, `DAI`, `BUSD`, `FDUSD`, `WBNB`

## Valuation

- Stablecoin quote pools are valued at `$1` per quote token.
- `WETH` and `WBNB` quote pools are priced with historical Chainlink USD feeds at
  the target block.
- Uniswap-v2-style pools use `getReserves()` and value total pool TVL as
  `2 * quote_side_usd`.
- Uniswap-v3-style pools use historical `slot0()` plus historical token
  balances at the pool address, then price the target token off the pool spot
  price at the target block.

## Why this is better

- It is point-in-time, not cumulative.
- It measures DEX liquidity, not transfers into the contract.
- It is block-aware, so benchmark positives can be evaluated at their exploit
  block rather than at some unrelated later date.

## Remaining gaps

- It does not yet cover every DEX venue, only the major factories in the local
  registry.
- It only counts direct pools against major quote assets.
- Curve, Balancer, Algebra/Thena-style pools, and long-tail DEXes are not yet
  included.

## Code

- Extractor: `classifier/historical_dex_liquidity.py`
- Recall merge: `classifier/analyze_filters.py`

## External references

- Anthropic paper: `https://red.anthropic.com/2025/smart-contracts/`
- `uniswap-smart-path` pivot-token approach:
  `https://github.com/Elnaril/uniswap-smart-path`
- Etherscan PRO endpoints:
  `https://docs.etherscan.io/resources/pro-endpoints`
