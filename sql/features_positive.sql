-- Feature extraction for positive (exploited) contracts

WITH targets(address, exploit_block) AS (VALUES
{addr_values}
),
creation AS (
    SELECT ct.address,
           length(ct.code) as bytecode_len,
           cardinality(array_distinct(regexp_extract_all(to_hex(ct.code), '.{2}'))) as unique_byte_pairs
    FROM {dune_creation} ct
    WHERE ct.address IN (SELECT address FROM targets)
      AND ct.block_time >= date '2015-01-01'
),
tx_stats AS (
    SELECT t."to" as address,
           COUNT(*) as tx_count,
           approx_distinct(t."from") as unique_callers,
           AVG(t.gas_used) as avg_gas
    FROM {dune_tx} t
    JOIN targets tgt ON t."to" = tgt.address AND t.block_number <= tgt.exploit_block
    WHERE t.block_time >= date '2015-01-01'
    GROUP BY 1
),
token_tvl AS (
    SELECT tt."to" as address,
           SUM(COALESCE(tt.amount_usd, 0)) as token_inflow_usd,
           COUNT(*) as token_transfer_count,
           approx_distinct(tt.contract_address) as distinct_tokens
    FROM tokens.transfers tt
    JOIN targets tgt ON tt."to" = tgt.address AND tt.block_number <= tgt.exploit_block
    WHERE tt.blockchain = '{dune_blockchain}'
      AND tt.amount_usd > 0
    GROUP BY 1
),
eth_tvl AS (
    SELECT tr."to" as address,
           SUM(CAST(tr.value AS DOUBLE)) / 1e18 as native_inflow
    FROM {dune_traces} tr
    JOIN targets tgt ON tr."to" = tgt.address AND tr.block_number <= tgt.exploit_block
    WHERE tr.block_time >= date '2015-01-01'
      AND CAST(tr.value AS DOUBLE) > 0 AND tr.success = true
    GROUP BY 1
),
verified AS (
    SELECT address FROM {dune_contracts}
    WHERE address IN (SELECT address FROM targets)
)
SELECT
    lower(cast(tgt.address as varchar)) as address,
    COALESCE(c.bytecode_len, 0) as bytecode_len,
    COALESCE(c.unique_byte_pairs, 0) as unique_byte_pairs,
    COALESCE(tx.tx_count, 0) as tx_count,
    COALESCE(tx.unique_callers, 0) as unique_callers,
    COALESCE(tx.avg_gas, 0) as avg_gas,
    COALESCE(ttv.token_transfer_count, 0) as token_transfer_count,
    COALESCE(ttv.distinct_tokens, 0) as distinct_tokens,
    COALESCE(ttv.token_inflow_usd, 0) + COALESCE(eth.native_inflow, 0) * {native_price_usd} as total_tvl_usd,
    CASE WHEN (COALESCE(ttv.token_inflow_usd, 0) + COALESCE(eth.native_inflow, 0) * {native_price_usd}) > 0
         THEN log10(COALESCE(ttv.token_inflow_usd, 0) + COALESCE(eth.native_inflow, 0) * {native_price_usd} + 1)
         ELSE 0 END as log_tvl
FROM targets tgt
LEFT JOIN creation c ON c.address = tgt.address
LEFT JOIN tx_stats tx ON tx.address = tgt.address
LEFT JOIN token_tvl ttv ON ttv.address = tgt.address
LEFT JOIN eth_tvl eth ON eth.address = tgt.address
