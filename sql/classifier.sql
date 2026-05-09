-- Smart Contract Exploitability Classifier
-- Universe: verified + TVL > $1k

WITH tvl_verified AS (
    SELECT tt."to" as address,
           SUM(COALESCE(tt.amount_usd, 0)) as token_inflow_usd,
           COUNT(*) as token_transfer_count,
           approx_distinct(tt.contract_address) as distinct_tokens
    FROM tokens.transfers tt
    WHERE tt.blockchain = '{dune_blockchain}'
      AND tt.block_time >= date '2020-01-01' AND tt.block_time < date '2026-04-01'
      AND tt.amount_usd > 0
      AND tt."to" != 0x0000000000000000000000000000000000000000
      AND tt."to" IN (SELECT DISTINCT address FROM {dune_contracts})
    GROUP BY 1
    HAVING SUM(COALESCE(tt.amount_usd, 0)) > 1000
),
creation AS (
    SELECT ct.address,
           length(ct.code) as bytecode_len,
           cardinality(array_distinct(regexp_extract_all(to_hex(ct.code), '.{2}'))) as unique_byte_pairs
    FROM {dune_creation} ct
    WHERE ct.address IN (SELECT address FROM tvl_verified)
      AND ct.block_time >= date '2015-01-01' AND length(ct.code) > 100
),
tx_stats AS (
    SELECT t."to" as address,
           COUNT(*) as tx_count,
           approx_distinct(t."from") as unique_callers,
           AVG(t.gas_used) as avg_gas
    FROM {dune_tx} t
    WHERE t."to" IN (SELECT address FROM creation)
      AND t.block_time >= date '2020-01-01' AND t.block_time < date '2026-04-01'
    GROUP BY 1
),
eth AS (
    SELECT tr."to" as address,
           SUM(CAST(tr.value AS DOUBLE)) / 1e18 as native_inflow
    FROM {dune_traces} tr
    WHERE tr."to" IN (SELECT address FROM creation)
      AND tr.block_time >= date '2020-01-01' AND tr.block_time < date '2026-04-01'
      AND CAST(tr.value AS DOUBLE) > 0 AND tr.success = true
    GROUP BY 1
),
features AS (
    SELECT
        c.address, c.bytecode_len, c.unique_byte_pairs,
        COALESCE(tx.tx_count, 0) as tx_count,
        COALESCE(tx.unique_callers, 0) as unique_callers,
        COALESCE(tx.avg_gas, 0) as avg_gas,
        tvl.token_transfer_count, tvl.distinct_tokens,
        tvl.token_inflow_usd + COALESCE(eth.native_inflow, 0) * {native_price_usd} as total_tvl_usd,
        CASE WHEN (tvl.token_inflow_usd + COALESCE(eth.native_inflow, 0) * {native_price_usd}) > 0
             THEN log10(tvl.token_inflow_usd + COALESCE(eth.native_inflow, 0) * {native_price_usd} + 1)
             ELSE 0 END as log_tvl
    FROM creation c
    JOIN tvl_verified tvl ON tvl.address = c.address
    LEFT JOIN tx_stats tx ON tx.address = c.address
    LEFT JOIN eth eth ON eth.address = c.address
)
SELECT address,
  (
{tree_sql}
  )
  + 0.20 * log10(CAST(COALESCE(avg_gas, 1) AS DOUBLE)) / 6.0
  + 0.10 * CAST(unique_byte_pairs AS DOUBLE) / 256.0
  + 0.08 * log10(CAST(COALESCE(unique_callers, 1) AS DOUBLE) + 1) / 6.0
  + 0.05 * CAST(log_tvl AS DOUBLE) / 12.0
  - 0.03 * log10(CAST(COALESCE(tx_count, 1) AS DOUBLE) + 1) / 8.0
  as exploit_score,
  bytecode_len, unique_byte_pairs, tx_count, unique_callers, avg_gas,
  token_transfer_count, distinct_tokens, total_tvl_usd, log_tvl
FROM features
ORDER BY exploit_score DESC
LIMIT 5000
