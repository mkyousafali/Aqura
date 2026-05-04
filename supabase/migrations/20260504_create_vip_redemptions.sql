-- VIP Redemptions table and supporting objects
-- Stores VIP customer redemption records with one-per-day enforcement

-- ============ Settings table (for activate/deactivate) ============
CREATE TABLE IF NOT EXISTS public.vip_campaign_settings (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    is_active       boolean NOT NULL DEFAULT false,
    activated_by    text,
    activated_at    timestamptz,
    notes           text,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);

-- Seed one row so there is always a settings record
INSERT INTO public.vip_campaign_settings (is_active)
SELECT false
WHERE NOT EXISTS (SELECT 1 FROM public.vip_campaign_settings);

-- ============ Redemptions table ============
CREATE TABLE IF NOT EXISTS public.vip_redemptions (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id      uuid,
    whatsapp_number  text NOT NULL,
    bill_number      text NOT NULL,
    bill_amount      numeric(12, 2) NOT NULL,
    discounted_value numeric(12, 2) NOT NULL,
    redeemed_date    date NOT NULL DEFAULT CURRENT_DATE,
    redeemed_at      timestamptz NOT NULL DEFAULT now(),
    cashier_id       text,
    branch_id        text,
    created_at       timestamptz NOT NULL DEFAULT now(),
    updated_at       timestamptz NOT NULL DEFAULT now(),

    -- One redemption per number per day
    CONSTRAINT vip_redemptions_number_date_unique UNIQUE (whatsapp_number, redeemed_date)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_vip_redemptions_whatsapp_number ON public.vip_redemptions (whatsapp_number);
CREATE INDEX IF NOT EXISTS idx_vip_redemptions_redeemed_date   ON public.vip_redemptions (redeemed_date);
CREATE INDEX IF NOT EXISTS idx_vip_redemptions_customer_id     ON public.vip_redemptions (customer_id);

-- ============ updated_at trigger ============
CREATE OR REPLACE FUNCTION public.set_vip_redemptions_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_vip_redemptions_updated_at ON public.vip_redemptions;
CREATE TRIGGER trg_vip_redemptions_updated_at
    BEFORE UPDATE ON public.vip_redemptions
    FOR EACH ROW EXECUTE FUNCTION public.set_vip_redemptions_updated_at();

DROP TRIGGER IF EXISTS trg_vip_campaign_settings_updated_at ON public.vip_campaign_settings;
CREATE TRIGGER trg_vip_campaign_settings_updated_at
    BEFORE UPDATE ON public.vip_campaign_settings
    FOR EACH ROW EXECUTE FUNCTION public.set_vip_redemptions_updated_at();

-- ============ RLS ============
ALTER TABLE public.vip_redemptions       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vip_campaign_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "vip_redemptions_all_authenticated"
    ON public.vip_redemptions FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "vip_redemptions_all_anon"
    ON public.vip_redemptions FOR ALL TO anon USING (true) WITH CHECK (true);

CREATE POLICY "vip_campaign_settings_all_authenticated"
    ON public.vip_campaign_settings FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "vip_campaign_settings_all_anon"
    ON public.vip_campaign_settings FOR ALL TO anon USING (true) WITH CHECK (true);

-- ============ Dashboard RPC ============
CREATE OR REPLACE FUNCTION public.get_vip_redemption_stats()
RETURNS json
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT json_build_object(
        'total_redemptions',   (SELECT COUNT(*)                      FROM vip_redemptions),
        'today_redemptions',   (SELECT COUNT(*)                      FROM vip_redemptions WHERE redeemed_date = CURRENT_DATE),
        'total_discount',      (SELECT COALESCE(SUM(discounted_value), 0) FROM vip_redemptions),
        'today_discount',      (SELECT COALESCE(SUM(discounted_value), 0) FROM vip_redemptions WHERE redeemed_date = CURRENT_DATE),
        'recent',              (
            SELECT COALESCE(json_agg(r ORDER BY r.redeemed_at DESC), '[]'::json)
            FROM (
                SELECT id, whatsapp_number, bill_number, bill_amount, discounted_value,
                       redeemed_date, redeemed_at, cashier_id, branch_id
                FROM vip_redemptions
                ORDER BY redeemed_at DESC
                LIMIT 50
            ) r
        )
    );
$$;

GRANT EXECUTE ON FUNCTION public.get_vip_redemption_stats() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_vip_redemption_stats() TO anon;
GRANT EXECUTE ON FUNCTION public.get_vip_redemption_stats() TO service_role;
