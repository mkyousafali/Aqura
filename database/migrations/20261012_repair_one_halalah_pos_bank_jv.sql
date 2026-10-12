BEGIN;

-- Before the generator handled the exact 0.01 boundary, it omitted the POS
-- Bank transfer JV while still including that halalah in the net adjustment.
-- Insert only the missing transfer into saved generated payloads. Existing
-- entries (including their posted flags) remain unchanged.
WITH candidates AS (
  SELECT
    bo.id,
    bo.ai_generated_entries,
    COALESCE(
      bo.difference_card_sales,
      NULLIF(bo.complete_details ->> 'difference_card_sales', '')::numeric,
      0
    ) AS card_difference,
    bo.ai_generated_entries #> '{entries,0}' AS receipt_entry,
    COALESCE(
      NULLIF(bo.ai_generated_entries #>> '{entries,0,credit_account}', ''),
      'POS Cash'
    ) AS pos_cash_account
  FROM public.box_operations bo
  WHERE bo.ai_generated_entries IS NOT NULL
    AND jsonb_typeof(bo.ai_generated_entries -> 'entries') = 'array'
    AND jsonb_array_length(bo.ai_generated_entries -> 'entries') > 0
    AND abs(COALESCE(
      bo.difference_card_sales,
      NULLIF(bo.complete_details ->> 'difference_card_sales', '')::numeric,
      0
    )) = 0.01
    AND NOT EXISTS (
      SELECT 1
      FROM jsonb_array_elements(bo.ai_generated_entries -> 'entries') AS entry
      WHERE entry ->> 'type' = 'transfer'
    )
), repaired AS (
  SELECT
    c.id,
    jsonb_set(
      c.ai_generated_entries,
      '{entries}',
      jsonb_build_array(c.receipt_entry)
      || jsonb_build_array(
        jsonb_build_object(
          'type', 'transfer',
          'form_name', 'JV',
          'description', CASE
            WHEN c.card_difference < 0 THEN 'Transfer card shortfall to POS Cash'
            ELSE 'Transfer card excess to POS Bank'
          END,
          'narration', CASE
            WHEN c.card_difference < 0 THEN 'Transfer card shortfall to POS Cash'
            ELSE 'Transfer card excess to POS Bank'
          END || CASE
            WHEN position(' - Cashier:' IN COALESCE(c.receipt_entry ->> 'narration', '')) > 0
              THEN substring(
                c.receipt_entry ->> 'narration'
                FROM position(' - Cashier:' IN c.receipt_entry ->> 'narration')
              )
            ELSE ''
          END,
          'debit_account', CASE
            WHEN c.card_difference < 0 THEN c.pos_cash_account
            ELSE 'POS Bank'
          END,
          'debit_amount', abs(c.card_difference),
          'credit_account', CASE
            WHEN c.card_difference < 0 THEN 'POS Bank'
            ELSE c.pos_cash_account
          END,
          'credit_amount', abs(c.card_difference),
          'posted', false
        )
      )
      || COALESCE(
        (
          SELECT jsonb_agg(entry ORDER BY ordinal)
          FROM jsonb_array_elements(c.ai_generated_entries -> 'entries')
            WITH ORDINALITY AS remaining(entry, ordinal)
          WHERE ordinal > 1
        ),
        '[]'::jsonb
      ),
      false
    ) AS ai_generated_entries
  FROM candidates c
)
UPDATE public.box_operations bo
SET ai_generated_entries = repaired.ai_generated_entries
FROM repaired
WHERE bo.id = repaired.id;

COMMIT;
