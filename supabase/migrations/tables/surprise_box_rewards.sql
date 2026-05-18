-- ============================================================
-- Surprise Box: Rewards Table
-- ============================================================
CREATE TABLE IF NOT EXISTS public.surprise_box_rewards (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    label_en text NOT NULL,
    label_ar text NOT NULL,
    voucher_value numeric NOT NULL DEFAULT 0,
    is_no_win boolean NOT NULL DEFAULT false,
    weight integer NOT NULL DEFAULT 1 CHECK (weight > 0),
    max_count integer,          -- NULL = unlimited
    issued_count integer NOT NULL DEFAULT 0,
    expiry_days integer NOT NULL DEFAULT 30,
    active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

-- Trigger: keep updated_at fresh
CREATE OR REPLACE FUNCTION public.surprise_box_rewards_set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_surprise_box_rewards_updated_at ON public.surprise_box_rewards;
CREATE TRIGGER trg_surprise_box_rewards_updated_at
    BEFORE UPDATE ON public.surprise_box_rewards
    FOR EACH ROW EXECUTE FUNCTION public.surprise_box_rewards_set_updated_at();

-- Row Level Security
ALTER TABLE public.surprise_box_rewards ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anon_all_surprise_box_rewards" ON public.surprise_box_rewards;
CREATE POLICY "anon_all_surprise_box_rewards"
    ON public.surprise_box_rewards FOR ALL TO anon USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "auth_all_surprise_box_rewards" ON public.surprise_box_rewards;
CREATE POLICY "auth_all_surprise_box_rewards"
    ON public.surprise_box_rewards FOR ALL TO authenticated USING (true) WITH CHECK (true);

GRANT ALL ON public.surprise_box_rewards TO anon;
GRANT ALL ON public.surprise_box_rewards TO authenticated;

-- Seed some default rewards
INSERT INTO public.surprise_box_rewards (label_en, label_ar, voucher_value, is_no_win, weight, expiry_days)
VALUES
    ('5 SAR Voucher',  'قسيمة 5 ريال',   5,   false, 30, 30),
    ('10 SAR Voucher', 'قسيمة 10 ريال',  10,   false, 25, 30),
    ('25 SAR Voucher', 'قسيمة 25 ريال',  25,   false, 15, 30),
    ('50 SAR Voucher', 'قسيمة 50 ريال',  50,   false,  8, 30),
    ('100 SAR Voucher','قسيمة 100 ريال', 100,  false,  2, 30),
    ('Better Luck!',   'حظ أوفر!',        0,   true,  20, 30)
ON CONFLICT DO NOTHING;
