-- ============================================================
-- Surprise Box: Settings Table
-- ============================================================
CREATE TABLE IF NOT EXISTS public.surprise_box_settings (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    active boolean NOT NULL DEFAULT false,
    start_datetime timestamptz,
    end_datetime timestamptz,
    daily_limit integer NOT NULL DEFAULT 100,
    minimum_bill_amount numeric NOT NULL DEFAULT 0,
    enforce_bill_date boolean NOT NULL DEFAULT true,
    box_count integer NOT NULL DEFAULT 6 CHECK (box_count BETWEEN 1 AND 12),
    terms_en text DEFAULT '',
    terms_ar text DEFAULT '',
    timezone text NOT NULL DEFAULT 'Asia/Riyadh',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

-- Ensure only one settings row exists
CREATE UNIQUE INDEX IF NOT EXISTS surprise_box_settings_singleton
    ON public.surprise_box_settings ((true));

-- Trigger: keep updated_at fresh
CREATE OR REPLACE FUNCTION public.surprise_box_settings_set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_surprise_box_settings_updated_at ON public.surprise_box_settings;
CREATE TRIGGER trg_surprise_box_settings_updated_at
    BEFORE UPDATE ON public.surprise_box_settings
    FOR EACH ROW EXECUTE FUNCTION public.surprise_box_settings_set_updated_at();

-- Row Level Security
ALTER TABLE public.surprise_box_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anon_all_surprise_box_settings" ON public.surprise_box_settings;
CREATE POLICY "anon_all_surprise_box_settings"
    ON public.surprise_box_settings FOR ALL TO anon USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "auth_all_surprise_box_settings" ON public.surprise_box_settings;
CREATE POLICY "auth_all_surprise_box_settings"
    ON public.surprise_box_settings FOR ALL TO authenticated USING (true) WITH CHECK (true);

GRANT ALL ON public.surprise_box_settings TO anon;
GRANT ALL ON public.surprise_box_settings TO authenticated;

-- Seed a default settings row if none exists
INSERT INTO public.surprise_box_settings (active, daily_limit, minimum_bill_amount, box_count)
SELECT false, 100, 0, 6
WHERE NOT EXISTS (SELECT 1 FROM public.surprise_box_settings);
