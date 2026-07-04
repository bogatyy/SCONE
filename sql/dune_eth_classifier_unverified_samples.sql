-- Hash-random samples from the Ethereum activity classifiers without Dune's
-- ethereum.contracts condition.
-- Window: contracts deployed from 2020-01-01 up to 2026-04-01.
--
-- The 2026-07-02 run used sample_rank <= 1000 for each classifier and then
-- checked Etherscan source verification with scripts/check_etherscan_verification.py.

WITH
params AS (
    SELECT DATE '2020-01-01' AS deploy_start, DATE '2026-04-01' AS deploy_end
),
deployed AS (
    SELECT
        ct.address,
        max(length(ct.code)) AS bytecode_len
    FROM ethereum.creation_traces ct
    CROSS JOIN params p
    WHERE ct.block_time >= p.deploy_start
      AND ct.block_time < p.deploy_end
    GROUP BY 1
),
tx_stats AS (
    SELECT
        t."to" AS address,
        COUNT(*) AS tx_count,
        approx_distinct(t."from") AS unique_callers
    FROM ethereum.transactions t
    CROSS JOIN params p
    WHERE t.block_time >= p.deploy_start
      AND t.block_time < p.deploy_end
      AND t."to" IS NOT NULL
    GROUP BY 1
),
base AS (
    SELECT
        d.address,
        d.bytecode_len,
        tx.tx_count,
        tx.unique_callers
    FROM deployed d
    JOIN tx_stats tx
      ON tx.address = d.address
    WHERE tx.tx_count >= 5
),
broad_sample AS (
    SELECT
        'broad' AS classifier,
        address,
        bytecode_len,
        tx_count,
        unique_callers,
        row_number() OVER (ORDER BY xxhash64(address)) AS sample_rank
    FROM base
),
tight_sample AS (
    SELECT
        'tight' AS classifier,
        address,
        bytecode_len,
        tx_count,
        unique_callers,
        row_number() OVER (ORDER BY xxhash64(address)) AS sample_rank
    FROM base
    WHERE bytecode_len >= 2000
      AND unique_callers >= 5
)
SELECT
    classifier,
    CAST(address AS varchar) AS address,
    bytecode_len,
    tx_count,
    unique_callers,
    sample_rank
FROM broad_sample
WHERE sample_rank <= 1000
UNION ALL
SELECT
    classifier,
    CAST(address AS varchar) AS address,
    bytecode_len,
    tx_count,
    unique_callers,
    sample_rank
FROM tight_sample
WHERE sample_rank <= 1000
ORDER BY classifier, sample_rank;
