-- Persisted AI-generated Entry to Pass (Gemini, CompleteBox.svelte's generatePosEntries()) so the
-- entries survive closing/reopening the window instead of only living in transient component state.

ALTER TABLE public.box_operations
    ADD COLUMN IF NOT EXISTS ai_generated_entries jsonb;

COMMENT ON COLUMN public.box_operations.ai_generated_entries IS
    'JSON result of the AI-generated Entry to Pass (Gemini) for this box operation — the raw {entries, final_balances, employee_charged, employee_charge_amount, notes} payload from /api/generate-pos-entries. Set on first "Generate Entries" click and overwritten on "Regenerate".';
