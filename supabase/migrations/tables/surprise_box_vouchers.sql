-- ============================================================
-- Surprise Box: Vouchers Table
-- ============================================================
CREATE TABLE IF NOT EXISTS public.surprise_box_vouchers (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code text UNIQUE NOT NULL,
    play_id uuid REFERENCES public.surprise_box_plays(id) ON DELETE SET NULL,
    reward_id uuid REFERENCES public.surprise_box_rewards(id) ON DELETE SET NULL,
    voucher_value numeric NOT NULL,
    label_en text,
    label_ar text,
    status text NOT NULL DEFAULT 'active'
        CHECK (status IN ('active','redeemed','expired','cancelled')),
    expires_at date NOT NULL,
    issued_at timestamptz NOT NULL DEFAULT now(),
    redeemed_at timestamptz,
    redeemed_amount numeric,
    redeemed_bill_number text,
    bill_number text,
    bill_amount numeric,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_surprise_box_vouchers_code       ON public.surprise_box_vouchers(code);
CREATE INDEX IF NOT EXISTS idx_surprise_box_vouchers_status     ON public.surprise_box_vouchers(status);
CREATE INDEX IF NOT EXISTS idx_surprise_box_vouchers_expires_at ON public.surprise_box_vouchers(expires_at);

-- Row Level Security
ALTER TABLE public.surprise_box_vouchers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anon_all_surprise_box_vouchers" ON public.surprise_box_vouchers;
CREATE POLICY "anon_all_surprise_box_vouchers"
    ON public.surprise_box_vouchers FOR ALL TO anon USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "auth_all_surprise_box_vouchers" ON public.surprise_box_vouchers;
CREATE POLICY "auth_all_surprise_box_vouchers"
    ON public.surprise_box_vouchers FOR ALL TO authenticated USING (true) WITH CHECK (true);

GRANT ALL ON public.surprise_box_vouchers TO anon;
GRANT ALL ON public.surprise_box_vouchers TO authenticated;
