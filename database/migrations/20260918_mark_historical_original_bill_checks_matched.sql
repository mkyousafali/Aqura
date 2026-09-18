BEGIN;

-- Business-approved historical override: Original Bill AI mismatches on receiving
-- records dated through 2026-08-31 are treated as matched regardless of the
-- individual AI mismatch reason. Preserve the extracted comparison details and
-- attach explicit override metadata for auditability.
UPDATE public.receiving_records
SET original_bill_check_result =
    jsonb_set(
        COALESCE(original_bill_check_result, '{}'::jsonb),
        '{status}',
        '"matched"'::jsonb,
        true
    ) || jsonb_build_object(
        'bulkOverride', true,
        'bulkOverrideAt', now(),
        'bulkOverrideReason', 'Historical Original Bill AI mismatches through 2026-08-31 approved as matched',
        'previousStatus', 'mismatch'
    )
WHERE bill_date <= DATE '2026-08-31'
  AND original_bill_check_result->>'status' = 'mismatch';

COMMIT;
