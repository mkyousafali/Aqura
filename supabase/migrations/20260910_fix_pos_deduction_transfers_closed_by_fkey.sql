-- pos_deduction_transfers.closed_by was pointed at auth.users(id), but the app
-- writes public.users.id (its own custom users table) into this column, same
-- as box_operations.completed_by_user_id / quick_task_completions.completed_by_user_id.
-- This caused FK violations (23503) for any user whose id isn't also present in auth.users.

ALTER TABLE public.pos_deduction_transfers
    DROP CONSTRAINT IF EXISTS pos_deduction_transfers_closed_by_fkey;

ALTER TABLE public.pos_deduction_transfers
    ADD CONSTRAINT pos_deduction_transfers_closed_by_fkey
    FOREIGN KEY (closed_by) REFERENCES public.users(id) ON DELETE SET NULL;
