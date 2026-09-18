BEGIN;

-- Refine the historical override: a failed bill-amount comparison remains a
-- blocking mismatch. Only rows touched by the 2026-09-18 bulk override qualify.
UPDATE public.receiving_records
SET original_bill_check_result =
    jsonb_set(original_bill_check_result, '{status}', '"mismatch"'::jsonb, true)
    || jsonb_build_object(
        'bulkOverride', false,
        'bulkOverrideRestoredAt', now(),
        'bulkOverrideRestoredReason', 'Bill amount mismatch must remain unmatched'
    )
WHERE bill_date <= DATE '2026-08-31'
  AND original_bill_check_result->>'bulkOverride' = 'true'
  AND original_bill_check_result->>'previousStatus' = 'mismatch'
  AND original_bill_check_result->>'billAmountMatches' = 'false';

COMMIT;
