-- Static comparison table for the three Ethereum classifiers discussed in this project.
-- Candidate counts are exact for classifiers 2 and 3.
-- Classifier 1 candidate count must be populated by running dune_eth_classifier1_true_liquidity.sql.

SELECT *
FROM (
    VALUES
        (
            'Classifier 1',
            'verified & erc20 & traded_in_september_2025 & historical_dex_liquidity_usd >= 1000',
            26,
            174,
            26.0 / 174.0,
            CAST(NULL AS BIGINT)
        ),
        (
            'Classifier 2',
            'verified & bytecode_len >= 2000 & tx_count >= 5 & unique_callers >= 5',
            103,
            174,
            103.0 / 174.0,
            28228
        ),
        (
            'Classifier 3',
            'verified & tx_count >= 5',
            136,
            174,
            136.0 / 174.0,
            228068
        )
) AS t(
    classifier,
    predicate,
    recall_hits,
    recall_total,
    recall_rate,
    candidate_contracts
);
