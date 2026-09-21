-- Append-only audit trail for the Windows Cashier Manager Cashier Counter flow.
BEGIN;

CREATE TABLE IF NOT EXISTS public.aqura_pos_print_actions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    flow_id uuid NOT NULL,
    user_id uuid NOT NULL REFERENCES public.users(id),
    branch_id bigint NOT NULL REFERENCES public.branches(id),
    action_type text NOT NULL CHECK (action_type IN (
        'printer_selection', 'test_print_attempt', 'test_print_success', 'test_print_failure',
        'opening_pos_counter', 'closing_pos_counter', 'recharge_card_operation',
        'other_reason', 'final_print_attempt', 'final_print_success', 'final_print_failure'
    )),
    reason text,
    custom_reason text,
    printer_name text NOT NULL,
    print_status text NOT NULL CHECK (print_status IN ('selected', 'attempted', 'success', 'failure', 'reason_selected')),
    error_message text,
    printed_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT aqura_pos_print_actions_printed_at_check CHECK (
        (print_status = 'success' AND printed_at IS NOT NULL) OR
        (print_status <> 'success' AND printed_at IS NULL)
    )
);

CREATE INDEX IF NOT EXISTS aqura_pos_print_actions_user_created_idx
    ON public.aqura_pos_print_actions (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS aqura_pos_print_actions_branch_created_idx
    ON public.aqura_pos_print_actions (branch_id, created_at DESC);
CREATE INDEX IF NOT EXISTS aqura_pos_print_actions_flow_idx
    ON public.aqura_pos_print_actions (flow_id, created_at);

ALTER TABLE public.aqura_pos_print_actions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.aqura_pos_print_actions FROM PUBLIC, anon, authenticated;
GRANT INSERT, SELECT ON public.aqura_pos_print_actions TO service_role;

COMMENT ON TABLE public.aqura_pos_print_actions IS
    'Append-only audit events for POS Manager Cashier Counter printer selection, test jobs, reason selection and final jobs.';

COMMIT;
