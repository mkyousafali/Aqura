-- ============================================================
-- Surprise Box: Plays Table
-- ============================================================
CREATE TABLE IF NOT EXISTS public.surprise_box_plays (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    bill_number text NOT NULL,
    bill_amount numeric NOT NULL,
    bill_date text,
    bill_image_url text,
    reward_id uuid REFERENCES public.surprise_box_rewards(id) ON DELETE SET NULL,
    voucher_code text,
    is_winner boolean NOT NULL DEFAULT false,
    rejected boolean NOT NULL DEFAULT false,
    reject_reason text,
    box_selected integer,           -- which box the customer tapped (1-N), analytics only
    manual_entry boolean NOT NULL DEFAULT false,
    manual_entry_by uuid,
    manual_entry_username text,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_surprise_box_plays_bill_number ON public.surprise_box_plays(bill_number);
CREATE INDEX IF NOT EXISTS idx_surprise_box_plays_created_at  ON public.surprise_box_plays(created_at);
CREATE INDEX IF NOT EXISTS idx_surprise_box_plays_voucher_code ON public.surprise_box_plays(voucher_code);

-- Row Level Security
ALTER TABLE public.surprise_box_plays ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anon_all_surprise_box_plays" ON public.surprise_box_plays;
CREATE POLICY "anon_all_surprise_box_plays"
    ON public.surprise_box_plays FOR ALL TO anon USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "auth_all_surprise_box_plays" ON public.surprise_box_plays;
CREATE POLICY "auth_all_surprise_box_plays"
    ON public.surprise_box_plays FOR ALL TO authenticated USING (true) WITH CHECK (true);

GRANT ALL ON public.surprise_box_plays TO anon;
GRANT ALL ON public.surprise_box_plays TO authenticated;
