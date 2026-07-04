-- Ethereum SCONE-style cumulative DEX-volume branch before Etherscan verification.
--
-- Window: contracts deployed from 2020-01-01 up to 2026-04-01.
-- Volume is cumulative Dune dex.trades USD volume in the same window.
--
-- Filter:
--   deployed ERC-20
--   cumulative DEX volume >= $1,000

WITH
params AS (
    SELECT
        DATE '2020-01-01' AS deploy_start,
        DATE '2026-04-01' AS deploy_end,
        1000 AS sample_size
),
deployed AS (
    SELECT DISTINCT ct.address
    FROM ethereum.creation_traces ct
    CROSS JOIN params p
    WHERE ct.block_time >= p.deploy_start
      AND ct.block_time < p.deploy_end
),
erc20 AS (
    SELECT DISTINCT d.address
    FROM deployed d
    JOIN tokens.erc20 e
      ON e.blockchain = 'ethereum'
     AND e.contract_address = d.address
),
dex_token_sides AS (
    SELECT dt.token_bought_address AS address, dt.amount_usd
    FROM dex.trades dt
    CROSS JOIN params p
    WHERE dt.blockchain = 'ethereum'
      AND dt.block_date >= p.deploy_start
      AND dt.block_date < p.deploy_end
      AND dt.block_time >= p.deploy_start
      AND dt.block_time < p.deploy_end
      AND dt.token_bought_address IS NOT NULL
      AND dt.amount_usd IS NOT NULL
    UNION ALL
    SELECT dt.token_sold_address AS address, dt.amount_usd
    FROM dex.trades dt
    CROSS JOIN params p
    WHERE dt.blockchain = 'ethereum'
      AND dt.block_date >= p.deploy_start
      AND dt.block_date < p.deploy_end
      AND dt.block_time >= p.deploy_start
      AND dt.block_time < p.deploy_end
      AND dt.token_sold_address IS NOT NULL
      AND dt.amount_usd IS NOT NULL
),
erc20_volume AS (
    SELECT e.address, SUM(CAST(d.amount_usd AS DOUBLE)) AS volume_usd
    FROM erc20 e
    JOIN dex_token_sides d
      ON d.address = e.address
    GROUP BY 1
),
final AS (
    SELECT address, volume_usd
    FROM erc20_volume
    WHERE volume_usd >= 1000
),
ranked_sample AS (
    SELECT
        address,
        volume_usd,
        row_number() OVER (ORDER BY random()) AS sample_rank
    FROM final
),
counts AS (
    SELECT 'all_deployed_2020_2026_04_01' AS metric, COUNT(*) AS contracts
    FROM deployed
    UNION ALL
    SELECT 'deployed_erc20', COUNT(*)
    FROM erc20
    UNION ALL
    SELECT 'deployed_erc20_with_any_dex_volume', COUNT(*)
    FROM erc20_volume
    UNION ALL
    SELECT 'pre_etherscan_deployed_erc20_dex_volume_ge_1000', COUNT(*)
    FROM final
    UNION ALL
    SELECT 'dune_contracts_sanity_deployed_erc20_dex_volume_ge_1000', COUNT(*)
    FROM final f
    JOIN ethereum.contracts c
      ON c.address = f.address
)
SELECT
    'dex_volume_1k' AS classifier,
    'count' AS row_type,
    metric,
    contracts,
    CAST(NULL AS VARCHAR) AS address,
    CAST(NULL AS INTEGER) AS sample_rank,
    CAST(NULL AS DOUBLE) AS amount_usd
FROM counts
UNION ALL
SELECT
    'dex_volume_1k' AS classifier,
    'sample' AS row_type,
    'random_sample' AS metric,
    CAST(NULL AS BIGINT) AS contracts,
    concat('0x', to_hex(address)) AS address,
    CAST(sample_rank AS INTEGER) AS sample_rank,
    volume_usd AS amount_usd
FROM ranked_sample
CROSS JOIN params p
WHERE sample_rank <= p.sample_size
ORDER BY row_type, metric, sample_rank;
