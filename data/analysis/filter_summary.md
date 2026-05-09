# Filter Summary

Generated on 2026-03-31 / 2026-04-01 from local artifacts plus Dune counts.

## Local Recall Highlights

### Ethereum positives

- `verified & tx_count >= 5`: 136 / 174 = 78.2%
- `verified & tx_count >= 5 & unique_callers >= 5`: 121 / 174 = 69.5%
- `verified & bytecode_len >= 2000 & tx_count >= 5 & unique_callers >= 5`: 103 / 174 = 59.2%
- `verified & erc20 & traded & total_transfer_in_usd >= 1k`: 18 / 174 = 10.3%

### BSC positives

- `verified & tx_count >= 5`: 198 / 216 = 91.7%
- `verified & tx_count >= 5 & unique_callers >= 5`: 185 / 216 = 85.6%
- `verified & bytecode_len >= 2000 & tx_count >= 5 & unique_callers >= 5`: 176 / 216 = 81.5%
- `verified & erc20 & traded & total_transfer_in_usd >= 1k`: 42 / 216 = 19.4%

## Dune Counts

### Ethereum since 2020-01-01

- `deployed_total`: 77,420,736
- `verified_count`: 1,938,152
- `erc20_count`: 1,348,254
- `traded_count`: 502,535
- `tx_count >= 5`: 1,538,969
- `unique_callers >= 5`: 725,085
- `verified & tx_count >= 5`: 228,068
- `verified & tx_count >= 5 & unique_callers >= 2`: 139,423
- `verified & tx_count >= 5 & unique_callers >= 5`: 72,217
- `verified & bytecode_len >= 2000 & tx_count >= 5 & unique_callers >= 5`: 28,228
- `verified & (traded or total_transfer_in_usd >= 1k)`: 776,588
- `verified & tx_count >= 5 & (traded or total_transfer_in_usd >= 1k)`: 147,933
- `verified & unique_callers >= 5 & (traded or total_transfer_in_usd >= 1k)`: 50,584
- `verified & erc20`: 527,202
- `verified & traded`: 8,427
- `erc20 & traded`: 498,612
- `verified & erc20 & traded & total_transfer_in_usd >= 1k`: 2,667

### BSC since 2020-01-01

- `deployed_total`: 335,706,183
- `verified_count`: 3,560,623
- `verified_erc20_count`: 2,427,219

## Current Recommendation State

- Ethereum:
  `verified & tx_count >= 5 & unique_callers >= 5` is the best exact match to the 30k-100k target band, with 72,217 contracts and 69.5% local recall.
- BSC:
  The local-recall winner is also activity-based (`verified & tx_count >= 5 & unique_callers >= 5`), but the exact since-2020 BSC count could not be completed because Dune returned a billing-cycle datapoint-limit error on the remaining BSC universe queries.

## Important Caveat

- `total_transfer_in_usd` is cumulative incoming token transfer value from the local pipeline. It is not the same thing as point-in-time DEX liquidity or true TVL.
