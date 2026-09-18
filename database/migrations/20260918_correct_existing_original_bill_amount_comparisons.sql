BEGIN;

-- One-time correction for already-persisted Original Bill AI checks. Earlier
-- checks compared the document amount with final_bill_amount. Recompute the
-- amount flag against bill_amount while preserving every extracted AI detail.
WITH parsed_amounts AS (
    SELECT
        r.id,
        replace(
            (regexp_match(
                r.original_bill_check_result->>'billAmountIncludingVat',
                '([0-9][0-9,]*(\.[0-9]+)?)'
            ))[1],
            ',',
            ''
        )::numeric AS extracted_amount
    FROM public.receiving_records r
    WHERE r.original_bill_check_result IS NOT NULL
      AND r.bill_amount IS NOT NULL
      AND r.original_bill_check_result->>'billAmountIncludingVat'
          ~ '([0-9][0-9,]*(\.[0-9]+)?)'
), corrected AS (
    SELECT
        r.id,
        abs(p.extracted_amount - r.bill_amount) < 0.05 AS amount_matches
    FROM public.receiving_records r
    JOIN parsed_amounts p ON p.id = r.id
)
UPDATE public.receiving_records r
SET original_bill_check_result =
    jsonb_set(
        r.original_bill_check_result,
        '{billAmountMatches}',
        to_jsonb(c.amount_matches),
        true
    ) || jsonb_build_object(
        'amountComparisonCorrectedAt', now(),
        'amountComparisonSource', 'bill_amount'
    )
FROM corrected c
WHERE c.id = r.id
  AND (r.original_bill_check_result->>'billAmountMatches')::boolean
      IS DISTINCT FROM c.amount_matches;

-- Promote only records that now satisfy the normal strict live-check rule.
-- Manual-verification and historical override statuses are otherwise preserved.
UPDATE public.receiving_records
SET original_bill_check_result =
    jsonb_set(original_bill_check_result, '{status}', '"matched"'::jsonb, true)
    || jsonb_build_object(
        'amountCorrectionStatusUpdatedAt', now(),
        'amountCorrectionPreviousStatus', 'mismatch'
    )
WHERE original_bill_check_result->>'status' = 'mismatch'
  AND original_bill_check_result->>'vendorMatches' = 'true'
  AND original_bill_check_result->>'billAmountMatches' = 'true'
  AND original_bill_check_result->>'billDateMatches' = 'true'
  -- Some legacy rows contain an orphaned accountant_user_id. A status change fires
  -- the receiving automation trigger, which correctly exposes that unrelated FK
  -- defect. Do not let those legacy rows abort the complete amount correction.
  AND (
      accountant_user_id IS NULL
      OR EXISTS (
          SELECT 1 FROM public.users u WHERE u.id = receiving_records.accountant_user_id
      )
  );

COMMIT;
