BEGIN;

-- One-time business override for checks that already exist at migration time.
-- A matching original-bill amount is sufficient for these historical records;
-- vendor/VAT and bill-date differences remain visible but do not block status.
-- The live AI-check implementation is intentionally unchanged.
UPDATE public.receiving_records
SET original_bill_check_result =
    jsonb_set(original_bill_check_result, '{status}', '"matched"'::jsonb, true)
    || jsonb_build_object(
        'existingAmountMatchOverride', true,
        'existingAmountMatchOverrideAt', now(),
        'existingAmountMatchOverrideReason', 'One-time approval: bill amount match is sufficient; other differences ignored',
        'existingAmountMatchPreviousStatus', 'mismatch'
    )
WHERE original_bill_check_result->>'status' = 'mismatch'
  AND original_bill_check_result->>'billAmountMatches' = 'true';

COMMIT;
