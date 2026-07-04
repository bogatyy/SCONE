-- Ethereum v2 direct major-quote peak-liquidity branch, with no September rule.
--
-- Window: contracts deployed from 2020-01-01 up to 2026-04-01.
--
-- Filter:
--   deployed ERC-20
--   has a direct Uniswap v2 or Sushi v2 pool against USDC/USDT/DAI/WETH
--   any one direct major-quote v2 pool reaches TVL >= $1,000 at any Sync event
--   during the window
--
-- This is intentionally a peak-pool predicate, not synchronized aggregate TVL
-- across all pools. It is the cheaper historical version of "v2 direct
-- major-quote liquidity >= $1k" and removes the bad September-2025 activity
-- condition.

WITH
params AS (
    SELECT
        DATE '2020-01-01' AS deploy_start,
        DATE '2026-04-01' AS deploy_end,
        1000 AS sample_size
),
quotes AS (
    SELECT * FROM (
        VALUES
            (0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48, 'USDC', 6, true),
            (0xdac17f958d2ee523a2206206994597c13d831ec7, 'USDT', 6, true),
            (0x6b175474e89094c44da98b954eedeac495271d0f, 'DAI', 18, true),
            (0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2, 'WETH', 18, false)
    ) AS t(quote_token, quote_symbol, quote_decimals, stable_quote)
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
v2_pairs AS (
    SELECT 'uniswap_v2' AS dex, pair, token0, token1
    FROM uniswap_v2_ethereum.factory_evt_paircreated pc
    CROSS JOIN params p
    WHERE pc.evt_block_date >= p.deploy_start
      AND pc.evt_block_date < p.deploy_end
    UNION ALL
    SELECT 'sushiswap_v2' AS dex, pair, token0, token1
    FROM sushi_ethereum.factory_evt_paircreated pc
    CROSS JOIN params p
    WHERE pc.evt_block_date >= p.deploy_start
      AND pc.evt_block_date < p.deploy_end
),
relevant_pairs AS (
    SELECT
        p.dex,
        p.pair,
        CASE WHEN p.token0 = q.quote_token THEN p.token1 ELSE p.token0 END AS candidate_token,
        q.quote_token,
        q.quote_symbol,
        q.quote_decimals,
        q.stable_quote,
        p.token0 = q.quote_token AS quote_is_token0
    FROM v2_pairs p
    JOIN quotes q
      ON q.quote_token = p.token0 OR q.quote_token = p.token1
    JOIN erc20 e
      ON e.address = CASE WHEN p.token0 = q.quote_token THEN p.token1 ELSE p.token0 END
),
weth_prices AS (
    SELECT CAST(pr.timestamp AS DATE) AS day, pr.price
    FROM prices.day pr
    CROSS JOIN params p
    WHERE pr.blockchain = 'ethereum'
      AND pr.contract_address = 0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2
      AND CAST(pr.timestamp AS DATE) >= p.deploy_start
      AND CAST(pr.timestamp AS DATE) < p.deploy_end
),
uniswap_peak AS (
    SELECT
        rp.candidate_token AS address,
        MAX(
            2
            * (
                CASE
                    WHEN rp.quote_is_token0 THEN CAST(s.reserve0 AS DOUBLE)
                    ELSE CAST(s.reserve1 AS DOUBLE)
                END
                / POW(10, CAST(rp.quote_decimals AS DOUBLE))
            )
            * CASE WHEN rp.stable_quote THEN 1.0 ELSE wp.price END
        ) AS peak_liquidity_usd
    FROM uniswap_v2_ethereum.pair_evt_sync s
    JOIN relevant_pairs rp
      ON rp.dex = 'uniswap_v2'
     AND rp.pair = s.contract_address
    LEFT JOIN weth_prices wp
      ON wp.day = s.evt_block_date
     AND rp.quote_symbol = 'WETH'
    CROSS JOIN params p
    WHERE s.evt_block_date >= p.deploy_start
      AND s.evt_block_date < p.deploy_end
    GROUP BY 1
),
sushi_peak AS (
    SELECT
        rp.candidate_token AS address,
        MAX(
            2
            * (
                CASE
                    WHEN rp.quote_is_token0 THEN CAST(s.reserve0 AS DOUBLE)
                    ELSE CAST(s.reserve1 AS DOUBLE)
                END
                / POW(10, CAST(rp.quote_decimals AS DOUBLE))
            )
            * CASE WHEN rp.stable_quote THEN 1.0 ELSE wp.price END
        ) AS peak_liquidity_usd
    FROM sushi_ethereum.pair_evt_sync s
    JOIN relevant_pairs rp
      ON rp.dex = 'sushiswap_v2'
     AND rp.pair = s.contract_address
    LEFT JOIN weth_prices wp
      ON wp.day = s.evt_block_date
     AND rp.quote_symbol = 'WETH'
    CROSS JOIN params p
    WHERE s.evt_block_date >= p.deploy_start
      AND s.evt_block_date < p.deploy_end
    GROUP BY 1
),
peak_by_token AS (
    SELECT address, MAX(peak_liquidity_usd) AS peak_liquidity_usd
    FROM (
        SELECT * FROM uniswap_peak
        UNION ALL
        SELECT * FROM sushi_peak
    )
    GROUP BY 1
),
final AS (
    SELECT address, peak_liquidity_usd
    FROM peak_by_token
    WHERE peak_liquidity_usd >= 1000
),
ranked_sample AS (
    SELECT
        address,
        peak_liquidity_usd,
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
    SELECT 'deployed_erc20_with_direct_major_quote_v2_pair', COUNT(DISTINCT candidate_token)
    FROM relevant_pairs
    UNION ALL
    SELECT 'deployed_erc20_with_any_direct_major_quote_v2_sync', COUNT(*)
    FROM peak_by_token
    UNION ALL
    SELECT 'pre_etherscan_peak_v2_direct_major_quote_liquidity_ge_1000', COUNT(*)
    FROM final
    UNION ALL
    SELECT 'dune_contracts_sanity_peak_v2_direct_major_quote_liquidity_ge_1000', COUNT(*)
    FROM final f
    JOIN ethereum.contracts c
      ON c.address = f.address
)
SELECT
    'peak_v2_liquidity_1k_no_september' AS classifier,
    'count' AS row_type,
    metric,
    contracts,
    CAST(NULL AS VARCHAR) AS address,
    CAST(NULL AS INTEGER) AS sample_rank,
    CAST(NULL AS DOUBLE) AS amount_usd
FROM counts
UNION ALL
SELECT
    'peak_v2_liquidity_1k_no_september' AS classifier,
    'sample' AS row_type,
    'random_sample' AS metric,
    CAST(NULL AS BIGINT) AS contracts,
    concat('0x', to_hex(address)) AS address,
    CAST(sample_rank AS INTEGER) AS sample_rank,
    peak_liquidity_usd AS amount_usd
FROM ranked_sample
CROSS JOIN params p
WHERE sample_rank <= p.sample_size
ORDER BY row_type, metric, sample_rank;
