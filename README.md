# SCONE Candidate Filters

I reproduced Anthropic's SCONE smart-contract candidate filter on Ethereum, then
built a replacement filter that improves recall from **15% to 60%** at a
comparable reduction ratio: from **77.4M Ethereum contracts** to **28,228
candidates**.

That is the central result. The original SCONE-style liquidity filter is
an excellent reduction mechanism, but on historical Ethereum exploits it misses
most of the targets. A simple activity-based classifier keeps the search space
small enough for expensive audit workflows while finding about four times as
many known exploited contracts.

## Headline Result

- Baseline reproduced: Anthropic / SCONE-style token-liquidity filter.
- Baseline recall: **26 / 174 = 14.9%** on known exploited Ethereum contracts.
- New tight classifier recall: **103 / 174 = 59.2%**.
- Candidate universe: **77,420,736** Ethereum contracts deployed between
  2020-01-01 and 2026-04-01.
- Tight classifier output: **28,228** candidates.
- Broader high-recall variant: **136 / 174 = 78.2%** recall at **228,068**
  candidates.

Production Dune queries:

- [60% recall at 28k candidates](https://dune.com/queries/6941487)
- [80% recall at 228k candidates](https://dune.com/queries/6941488)

The motivation comes from Anthropic's SCONE-bench work:
[AI agents find $4.6M in blockchain smart contract exploits](https://red.anthropic.com/2025/smart-contracts/).
SCONE-bench evaluates agents against real historical exploits and describes a
prefiltering pipeline for shrinking a large deployed-contract universe into a
small audit queue.

## Comparison

I evaluated candidate filters against 174 exploited Ethereum contracts derived
from DeFiHackLabs / SCONE-bench and compared them to the full Ethereum deployed
contract universe since 2020.

| Filter | Predicate | Candidates | Recall |
| --- | --- | ---: | ---: |
| Anthropic / SCONE-style liquidity branch | verified, ERC-20, traded, historical DEX liquidity >= $1k | small liquidity-focused set | 26 / 174 = 14.9% |
| Tight activity classifier | verified, bytecode length >= 2,000, tx count >= 5, unique callers >= 5 | 28,228 | 103 / 174 = 59.2% |
| Broad activity classifier | verified, tx count >= 5 | 228,068 | 136 / 174 = 78.2% |

The tight classifier keeps roughly the same order of candidate-set reduction as
the SCONE-style baseline while improving Ethereum exploit recall from about 15%
to about 60%. The broader classifier expands the candidate set by about one
order of magnitude and reaches about 80% recall.

## Baseline

The Anthropic / SCONE-style prefilter is represented here as the
token-liquidity branch:

- source verified,
- ERC-20 shaped,
- traded,
- historical direct DEX liquidity >= $1,000.

Measured against the Ethereum exploit set, this passes 26 of 174 known
exploited contracts, or 14.9% recall. That is the baseline the activity
classifiers improve on.

## Method

1. Start with the SCONE-bench / DeFiHackLabs historical exploit set.
2. Extract vulnerable contract addresses and exploit blocks.
3. Build features for exploited contracts and sampled non-exploited contracts:
   verification status, ERC-20 shape, bytecode size, transaction count, unique
   caller count, gas usage, token transfer activity, and trading/liquidity
   indicators.
4. Compare filters and filter intersections against the positive set.
5. Port the strongest filters to Dune SQL to count the Ethereum candidate
   universe since 2020.

The core metric is recall on historical exploited Ethereum contracts at a given
candidate-set size. The goal is the first stage of a defensive audit pipeline:
avoid missing known-vulnerable patterns before sending candidates to slower
manual or agentic analysis.

## Numbers

- Ethereum deployed contracts since 2020-01-01: **77,420,736**
- Verified contracts: **1,938,152**
- Verified contracts with tx count >= 5: **228,068**
- Verified contracts with tx count >= 5 and unique callers >= 5: **72,217**
- Verified contracts with bytecode length >= 2,000, tx count >= 5, and unique
  callers >= 5: **28,228**

Local Ethereum recall:

- verified and tx count >= 5: **136 / 174 = 78.2%**
- verified, tx count >= 5, unique callers >= 5: **121 / 174 = 69.5%**
- verified, bytecode length >= 2,000, tx count >= 5, unique callers >= 5:
  **103 / 174 = 59.2%**
- verified, ERC-20, traded, historical DEX liquidity >= $1k:
  **26 / 174 = 14.9%**
