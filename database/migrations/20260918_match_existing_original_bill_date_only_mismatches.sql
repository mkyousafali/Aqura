BEGIN;

-- One-time correction for checks that already exist as of this migration.
-- When vendor/VAT and bill amount both match, a bill-date difference alone
-- must not keep the historical check in mismatch. Future check logic is not changed.
UPDATE public.receiving_records
SET original_bill_check_result =
    jsonb_set(original_bill_check_result, '{status}', '"matched"'::jsonb, true)
    || jsonb_build_object(
        'dateMismatchOverride', true,
        'dateMismatchOverrideAt', now(),
        'dateMismatchOverrideReason', 'Existing check approved because vendor and bill amount match; bill date ignored',
        'previousStatus', 'mismatch'
    )
WHERE original_bill_check_result->>'status' = 'mismatch'
  AND original_bill_check_result->>'vendorMatches' = 'true'
  AND original_bill_check_result->>'billAmountMatches' = 'true';

COMMIT;
