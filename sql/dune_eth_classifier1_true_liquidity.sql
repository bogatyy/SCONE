-- Ethereum classifier 1 count query.
-- Window matches the prior analysis: contracts deployed from 2020-01-01 up to 2026-04-01.
--
-- Classifier 1:
--   verified
--   ERC-20
--   traded at least once in September 2025
--   direct major-quote DEX liquidity >= $1,000 on 2025-10-03
--
-- This is the Dune version of the "true liquidity" redesign:
--   - Uniswap v2
--   - SushiSwap v2
--   - Uniswap v3
--   - quote assets = USDC, USDT, DAI, WETH
--
-- Notes:
--   - v2 TVL uses 2 * quote-side USD reserve from the latest Sync before 2025-10-04.
--   - v3 TVL uses daily pool token balances on 2025-10-03 and prices from prices.day.
--   - If your Dune workspace uses a different daily-balance snapshot table than
--     tokens_ethereum.balances_daily, swap that table in below.

WITH
params AS (
    SELECT
        DATE '2020-01-01' AS deploy_start,
        DATE '2026-04-01' AS deploy_end,
        DATE '2025-09-01' AS sept_start,
        DATE '2025-10-01' AS oct_start,
        DATE '2025-10-03' AS liq_day,
        DATE '2025-10-04' AS liq_day_next
),
quotes AS (
    SELECT * FROM (
        VALUES
            (from_hex('a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48'), 'USDC'),
            (from_hex('dac17f958d2ee523a2206206994597c13d831ec7'), 'USDT'),
            (from_hex('6b175474e89094c44da98b954eedeac495271d0f'), 'DAI'),
            (from_hex('c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2'), 'WETH')
    ) AS t(quote_token, quote_symbol)
),
deployed AS (
    SELECT DISTINCT ct.address, length(ct.code) AS bytecode_len
    FROM ethereum.creation_traces ct
    CROSS JOIN params p
    WHERE ct.block_time >= p.deploy_start
      AND ct.block_time < p.deploy_end
),
verified_erc20 AS (
    SELECT DISTINCT d.address, d.bytecode_len
    FROM deployed d
    JOIN ethereum.contracts c
      ON c.address = d.address
    JOIN tokens.erc20 e
      ON e.blockchain = 'ethereum'
     AND e.contract_address = d.address
),
traded_in_september AS (
    SELECT DISTINCT token_address AS address
    FROM (
        SELECT dt.token_bought_address AS token_address
        FROM dex.trades dt
        CROSS JOIN params p
        WHERE dt.blockchain = 'ethereum'
          AND dt.block_time >= p.sept_start
          AND dt.block_time < p.oct_start
        UNION
        SELECT dt.token_sold_address AS token_address
        FROM dex.trades dt
        CROSS JOIN params p
        WHERE dt.blockchain = 'ethereum'
          AND dt.block_time >= p.sept_start
          AND dt.block_time < p.oct_start
    )
),
candidate_tokens AS (
    SELECT DISTINCT v.address
    FROM verified_erc20 v
    JOIN traded_in_september t
      ON t.address = v.address
),
v2_pairs AS (
    SELECT pair, token0, token1
    FROM uniswap_v2_ethereum.factory_evt_paircreated
    UNION
    SELECT pair, token0, token1
    FROM sushi_ethereum.factory_evt_paircreated
),
relevant_v2_pairs AS (
    SELECT
        p.pair,
        CASE
            WHEN p.token0 = c.address THEN p.token0
            WHEN p.token1 = c.address THEN p.token1
        END AS candidate_token,
        CASE
            WHEN p.token0 = c.address THEN p.token1
            WHEN p.token1 = c.address THEN p.token0
        END AS quote_token
    FROM v2_pairs p
    JOIN candidate_tokens c
      ON p.token0 = c.address OR p.token1 = c.address
    JOIN quotes q
      ON q.quote_token = p.token0 OR q.quote_token = p.token1
),
relevant_v2_pair_ids AS (
    SELECT DISTINCT pair
    FROM relevant_v2_pairs
),
v2_sync_ranked AS (
    SELECT
        s.contract_address AS pair,
        s.reserve0,
        s.reserve1,
        row_number() OVER (
            PARTITION BY s.contract_address
            ORDER BY s.evt_block_number DESC, s.evt_index DESC
        ) AS rn
    FROM uniswap_v2_ethereum.pair_evt_sync s
    JOIN relevant_v2_pair_ids rp
      ON rp.pair = s.contract_address
    CROSS JOIN params p
    WHERE s.evt_block_time < CAST(p.liq_day_next AS TIMESTAMP)
    UNION ALL
    SELECT
        s.contract_address AS pair,
        s.reserve0,
        s.reserve1,
        row_number() OVER (
            PARTITION BY s.contract_address
            ORDER BY s.evt_block_number DESC, s.evt_index DESC
        ) AS rn
    FROM sushi_ethereum.pair_evt_sync s
    JOIN relevant_v2_pair_ids rp
      ON rp.pair = s.contract_address
    CROSS JOIN params p
    WHERE s.evt_block_time < CAST(p.liq_day_next AS TIMESTAMP)
),
latest_v2_sync AS (
    SELECT pair, reserve0, reserve1
    FROM v2_sync_ranked
    WHERE rn = 1
),
quote_prices AS (
    SELECT pr.contract_address AS quote_token, pr.price
    FROM prices.day pr
    CROSS JOIN params x
    WHERE pr.blockchain = 'ethereum'
      AND CAST(pr.timestamp AS DATE) = x.liq_day
      AND pr.contract_address IN (SELECT quote_token FROM quotes)
),
v2_liquidity AS (
    SELECT
        rp.candidate_token AS address,
        SUM(
            CASE
                WHEN rp.quote_token = l.token0
                    THEN 2 * (CAST(ls.reserve0 AS DOUBLE) / POW(10, CAST(t0.decimals AS DOUBLE))) * qp.price
                ELSE 2 * (CAST(ls.reserve1 AS DOUBLE) / POW(10, CAST(t1.decimals AS DOUBLE))) * qp.price
            END
        ) AS liquidity_usd
    FROM relevant_v2_pairs rp
    JOIN latest_v2_sync ls
      ON ls.pair = rp.pair
    JOIN v2_pairs l
      ON l.pair = rp.pair
    JOIN tokens.erc20 t0
      ON t0.blockchain = 'ethereum'
     AND t0.contract_address = l.token0
    JOIN tokens.erc20 t1
      ON t1.blockchain = 'ethereum'
     AND t1.contract_address = l.token1
    JOIN quote_prices qp
      ON qp.quote_token = rp.quote_token
    GROUP BY 1
),
relevant_v3_pools AS (
    SELECT
        pc.pool,
        CASE
            WHEN pc.token0 = c.address THEN pc.token0
            WHEN pc.token1 = c.address THEN pc.token1
        END AS candidate_token,
        CASE
            WHEN pc.token0 = c.address THEN pc.token1
            WHEN pc.token1 = c.address THEN pc.token0
        END AS quote_token
    FROM uniswap_v3_ethereum.factory_evt_poolcreated pc
    JOIN candidate_tokens c
      ON pc.token0 = c.address OR pc.token1 = c.address
    JOIN quotes q
      ON q.quote_token = pc.token0 OR q.quote_token = pc.token1
),
v3_balances AS (
    SELECT
        b.address AS pool,
        b.token_address,
        b.balance,
        b.balance_usd
    FROM tokens_ethereum.balances_daily b
    CROSS JOIN params p
    WHERE b.day = p.liq_day
),
v3_liquidity AS (
    SELECT
        rp.candidate_token AS address,
        SUM(COALESCE(qb.balance_usd, 0) + COALESCE(cb.balance_usd, 0)) AS liquidity_usd
    FROM relevant_v3_pools rp
    LEFT JOIN v3_balances qb
      ON qb.pool = rp.pool
     AND qb.token_address = rp.quote_token
    LEFT JOIN v3_balances cb
      ON cb.pool = rp.pool
     AND cb.token_address = rp.candidate_token
    GROUP BY 1
),
all_liquidity AS (
    SELECT address, SUM(liquidity_usd) AS liquidity_usd
    FROM (
        SELECT * FROM v2_liquidity
        UNION ALL
        SELECT * FROM v3_liquidity
    )
    GROUP BY 1
)
SELECT COUNT(DISTINCT c.address) AS candidate_contracts
FROM candidate_tokens c
JOIN all_liquidity l
  ON l.address = c.address
WHERE l.liquidity_usd >= 1000;
