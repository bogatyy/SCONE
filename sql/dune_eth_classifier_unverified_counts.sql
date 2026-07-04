-- Ethereum activity-classifier counts without Dune's ethereum.contracts condition.
-- Window: contracts deployed from 2020-01-01 up to 2026-04-01.
--
-- Rerun on 2026-07-02 UTC:
--   all deployed contracts: 77,207,055
--   broad, no verified condition: 1,536,919
--   tight, no verified condition: 497,585
--   broad, Dune-verified sanity check: 228,319
--   tight, Dune-verified sanity check: 28,364
--
-- Important: ethereum.contracts is Dune's decoded/verified subset. It is not
-- equivalent to Etherscan source verification.

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
verified AS (
    SELECT DISTINCT address
    FROM ethereum.contracts
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
        tx.unique_callers,
        v.address IS NOT NULL AS dune_verified
    FROM deployed d
    JOIN tx_stats tx
      ON tx.address = d.address
    LEFT JOIN verified v
      ON v.address = d.address
    WHERE tx.tx_count >= 5
),
counts AS (
    SELECT 'all_deployed_2020_2026_04_01' AS metric, COUNT(*) AS contracts FROM deployed
    UNION ALL
    SELECT 'broad_no_verified_tx5', COUNT(*) FROM base
    UNION ALL
    SELECT 'tight_no_verified_bytecode2000_tx5_callers5', COUNT(*)
    FROM base
    WHERE bytecode_len >= 2000 AND unique_callers >= 5
    UNION ALL
    SELECT 'broad_dune_verified_tx5_sanity', COUNT(*) FROM base WHERE dune_verified
    UNION ALL
    SELECT 'tight_dune_verified_bytecode2000_tx5_callers5_sanity', COUNT(*)
    FROM base
    WHERE dune_verified AND bytecode_len >= 2000 AND unique_callers >= 5
)
SELECT *
FROM counts
ORDER BY metric;
