# SCONE Candidate Filters

I’m building an efficient audit pipeline for discovering novel smart contract vulnerabilities.  
The setup is inspired by Anthropic’s two-stage [SCONE pipeline](https://www.anthropic.com/research/smart-contracts): first filter for promising contracts, then run LLM-powered audits on the selected candidates.

My contribution improves the filtering stage.
SCONE’s original filter catches about **15%** of past Ethereum exploits. The filter I’m proposing catches about **60%**, while producing roughly the same number of candidates.
If past exploit recall is a decent proxy for future vulnerability recall, then swapping in this filter could make the same audit budget about **4x more effective**.

Using this audit pipeline, I recently found a novel, full-drain ZK circuit [vulnerability](https://x.com/ivanbogatyy/status/2069159603942596830) in a contract that had previously held $2M.

## Headline Numbers

| Filter | Predicate | Candidates | Recall |
| --- | --- | ---: | ---: |
| Original Anthropic SCONE filter | source code verified<br>ERC-20<br>traded on a DEX<br>DEX liquidity >= $1k | ~382,000 | 26 / 174 = 14.9% |
| Suggested new filter | source code verified<br>tx count >= 5<br>bytecode length >= 2,000<br>unique callers >= 5 | ~411,000 | 103 / 174 = 59.2% |
| Higher-recall alternative | source code verified<br>tx count >= 5 | ~987,000 | 136 / 174 = 78.2% |

Candidate universe: Ethereum contracts deployed from `2020-01-01` up to
`2026-04-01`.

All features except "source code verified" are calculated using Dune SQL.

Etherscan verification status is not available on Dune, so I calculate it directly as the last filtering step (also, it is too expensive to API-request for each contract, so I do random sampling).

**Errata:** in the previous version of this repo, candidate set sizes were wrong due to a divergence between "Dune verified contracts" and "Etherscan verified contracts"; this is fixed now. Recall numbers were not affected.

Historical DEX liquidity >= $1k is calculated adding up all v2 and v3 liquidity.

## Benchmark Recall

The original
[`benchmark.csv`](https://github.com/safety-research/SCONE-bench/blob/main/benchmark.csv)
has 177 Ethereum rows and 174 unique Ethereum target addresses. The
unique-address denominator is used for the headline recall numbers.

| Stage | Passing contracts | Recall |
| --- | ---: | ---: |
| Ethereum mainnet positives | 174 | 100.0% |
| Implements ERC-20 runtime core | 59 | 33.9% |
| ERC-20 and Etherscan source verified | 59 | 33.9% |
| ERC-20, verified, historical DEX liquidity >= $1k | 26 | 14.9% |

## Universe Reductions

SCONE-style per-stage reductions, plus a volume-based alternative:

| Step | Liquidity branch | DEX-volume alternative |
| --- | ---: | ---: |
| Ethereum deployed contracts, `2020-01-01` to `2026-04-01` | 77,207,055 | 77,207,055 |
| Deployed ERC-20s | 1,348,507 | 1,348,507 |
| Market evidence | 480,845 direct major-quote v2 pair | 497,137 any DEX volume |
| Active market/liquidity threshold | 466,090 any direct major-quote v2 Sync event | 370,574 DEX volume >= $1k |
| Final pre-Etherscan predicate | 445,658 peak v2 direct major-quote liquidity >= $1k | 370,574 DEX volume >= $1k |
| Estimated Etherscan-verified candidates | 382,375 | 329,440 |

Activity classifiers:

| Step | Count |
| --- | ---: |
| Tight activity classifier, pre-Etherscan | 497,585 |
| Tight activity classifier, estimated Etherscan-verified | 411,005 |
| Broad activity classifier, pre-Etherscan | 1,536,919 |
| Broad activity classifier, estimated Etherscan-verified | 986,702 |


## Artifacts

SQL queries:

- `sql/dune_eth_scone_v2_peak_liquidity_no_september_count_sample.sql`
- `sql/dune_eth_scone_volume_unverified_count_sample.sql`
- `sql/dune_eth_classifier_unverified_counts.sql`
- `sql/dune_eth_classifier_unverified_samples.sql`

Resulting Data:

- `data/analysis/ethereum_true_liquidity.csv`
- `data/analysis/ethereum_filter_recall.csv`
- `data/analysis/scone_peak_v2_liquidity_no_september_etherscan_estimate.json`
- `data/analysis/scone_volume_1k_etherscan_estimate.json`
- `data/analysis/etherscan_verification_estimate.json`
