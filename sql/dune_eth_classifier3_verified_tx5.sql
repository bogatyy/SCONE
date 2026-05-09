-- Ethereum classifier 3 count query.
-- Exact count previously observed: 228,068
-- Window: contracts deployed from 2020-01-01 up to 2026-04-01.
--
-- Classifier 3:
--   verified
--   tx_count >= 5

WITH
params AS (
    SELECT DATE '2020-01-01' AS deploy_start, DATE '2026-04-01' AS deploy_end
),
deployed AS (
    SELECT DISTINCT ct.address
    FROM ethereum.creation_traces ct
    CROSS JOIN params p
    WHERE ct.block_time >= p.deploy_start
      AND ct.block_time < p.deploy_end
),
verified AS (
    SELECT DISTINCT d.address
    FROM deployed d
    JOIN ethereum.contracts c
      ON c.address = d.address
),
tx_stats AS (
    SELECT
        t."to" AS address,
        COUNT(*) AS tx_count
    FROM ethereum.transactions t
    CROSS JOIN params p
    WHERE t.block_time >= p.deploy_start
      AND t.block_time < p.deploy_end
      AND t."to" IS NOT NULL
    GROUP BY 1
)
SELECT COUNT(DISTINCT v.address) AS candidate_contracts
FROM verified v
JOIN tx_stats tx
  ON tx.address = v.address
WHERE tx.tx_count >= 5;
