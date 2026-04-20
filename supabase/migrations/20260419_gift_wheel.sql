-- Gift Wheel Feature - Database Tables and RPC Functions
-- Created: 2026-04-19

-- ============================================================
-- 1. GIFT WHEEL SETTINGS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS public.gift_wheel_settings (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    active boolean NOT NULL DEFAULT false,
    start_datetime timestamptz,
    end_datetime timestamptz,
    daily_limit integer NOT NULL DEFAULT 100,
    timezone text NOT NULL DEFAULT 'Asia/Riyadh',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

-- Insert default settings row
INSERT INTO public.gift_wheel_settings (active, daily_limit, timezone)
VALUES (false, 100, 'Asia/Riyadh')
ON CONFLICT DO NOTHING;

ALTER TABLE public.gift_wheel_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow authenticated all gift_wheel_settings"
    ON public.gift_wheel_settings FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Allow anon all gift_wheel_settings"
    ON public.gift_wheel_settings FOR ALL TO anon USING (true) WITH CHECK (true);

-- ============================================================
-- 2. GIFT WHEEL REWARDS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS public.gift_wheel_rewards (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    label text NOT NULL,
    reward_type text NOT NULL DEFAULT 'percentage' CHECK (reward_type IN ('percentage', 'fixed', 'no_reward')),
    value numeric NOT NULL DEFAULT 0,
    max_discount numeric DEFAULT NULL,
    min_bill numeric NOT NULL DEFAULT 0,
    weight integer NOT NULL DEFAULT 1,
    usage_limit integer DEFAULT NULL,
    usage_count integer NOT NULL DEFAULT 0,
    validity_days integer NOT NULL DEFAULT 7,
    reward_label_en text,
    reward_label_ar text,
    active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.gift_wheel_rewards ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow authenticated all gift_wheel_rewards"
    ON public.gift_wheel_rewards FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Allow anon all gift_wheel_rewards"
    ON public.gift_wheel_rewards FOR ALL TO anon USING (true) WITH CHECK (true);

-- Insert default rewards
INSERT INTO public.gift_wheel_rewards (label, reward_type, value, max_discount, min_bill, weight, validity_days, active) VALUES
    ('Better luck next time', 'no_reward', 0, NULL, 0, 40, 7, true),
    ('2% Off', 'percentage', 2, NULL, 0, 25, 7, true),
    ('5% Off', 'percentage', 5, NULL, 0, 18, 7, true),
    ('10% Off', 'percentage', 10, NULL, 0, 10, 7, true),
    ('15% Off', 'percentage', 15, NULL, 500, 5, 7, true),
    ('50% Off', 'percentage', 50, NULL, 500, 2, 7, true);

-- ============================================================
-- 3. GIFT WHEEL COUPONS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS public.gift_wheel_coupons (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code text UNIQUE NOT NULL,
    reward_id uuid NOT NULL REFERENCES public.gift_wheel_rewards(id) ON DELETE CASCADE,
    reward_label text,
    reward_label_en text,
    reward_label_ar text,
    reward_type text,
    reward_value numeric,
    max_discount numeric,
    expiry_date date,
    printed_at timestamptz,
    redeemed_at timestamptz,
    redeemed_amount numeric,
    status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'printed', 'redeemed', 'expired', 'cancelled')),
    branch_id text,
    bill_number text,
    bill_amount numeric,
    bill_date text,
    redeemed_bill_number text,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_gift_wheel_coupons_code ON public.gift_wheel_coupons(code);
CREATE INDEX IF NOT EXISTS idx_gift_wheel_coupons_status ON public.gift_wheel_coupons(status);

ALTER TABLE public.gift_wheel_coupons ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow authenticated all gift_wheel_coupons"
    ON public.gift_wheel_coupons FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Allow anon all gift_wheel_coupons"
    ON public.gift_wheel_coupons FOR ALL TO anon USING (true) WITH CHECK (true);

-- ============================================================
-- 4. GIFT WHEEL SPINS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS public.gift_wheel_spins (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    bill_number text NOT NULL,
    bill_amount numeric NOT NULL DEFAULT 0,
    bill_date text,
    bill_image_url text,
    reward_id uuid REFERENCES public.gift_wheel_rewards(id),
    reward_label text,
    coupon_code text,
    is_winner boolean NOT NULL DEFAULT false,
    rejected boolean NOT NULL DEFAULT false,
    reject_reason text,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_gift_wheel_spins_bill_number ON public.gift_wheel_spins(bill_number);
CREATE INDEX IF NOT EXISTS idx_gift_wheel_spins_created_at ON public.gift_wheel_spins(created_at);

ALTER TABLE public.gift_wheel_spins ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow authenticated all gift_wheel_spins"
    ON public.gift_wheel_spins FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Allow anon all gift_wheel_spins"
    ON public.gift_wheel_spins FOR ALL TO anon USING (true) WITH CHECK (true);

-- ============================================================
-- 5. RPC: CHECK GIFT WHEEL STATUS
-- ============================================================
CREATE OR REPLACE FUNCTION public.gift_wheel_check_status()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    settings_row gift_wheel_settings%ROWTYPE;
    spins_today integer;
    now_riyadh timestamptz;
    result jsonb;
BEGIN
    SELECT * INTO settings_row FROM gift_wheel_settings LIMIT 1;

    IF settings_row IS NULL THEN
        RETURN jsonb_build_object('active', false, 'reason', 'not_configured');
    END IF;

    IF NOT settings_row.active THEN
        RETURN jsonb_build_object('active', false, 'reason', 'disabled');
    END IF;

    now_riyadh := now() AT TIME ZONE settings_row.timezone;

    -- Check scheduled time
    IF settings_row.start_datetime IS NOT NULL AND now() < settings_row.start_datetime THEN
        RETURN jsonb_build_object('active', false, 'reason', 'not_started');
    END IF;

    IF settings_row.end_datetime IS NOT NULL AND now() > settings_row.end_datetime THEN
        RETURN jsonb_build_object('active', false, 'reason', 'ended');
    END IF;

    -- Check daily limit
    SELECT count(*) INTO spins_today
    FROM gift_wheel_spins
    WHERE (created_at AT TIME ZONE settings_row.timezone)::date = now_riyadh::date
      AND rejected = false;

    IF spins_today >= settings_row.daily_limit THEN
        RETURN jsonb_build_object('active', false, 'reason', 'daily_limit_reached', 'spins_today', spins_today);
    END IF;

    RETURN jsonb_build_object(
        'active', true,
        'spins_today', spins_today,
        'daily_limit', settings_row.daily_limit,
        'remaining', settings_row.daily_limit - spins_today
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.gift_wheel_check_status() TO authenticated;
GRANT EXECUTE ON FUNCTION public.gift_wheel_check_status() TO anon;

-- ============================================================
-- 6. RPC: VALIDATE BILL AND SPIN
-- ============================================================
CREATE OR REPLACE FUNCTION public.gift_wheel_spin(
    p_bill_number text,
    p_bill_amount numeric,
    p_bill_image_url text DEFAULT NULL,
    p_bill_date text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    settings_row gift_wheel_settings%ROWTYPE;
    spins_today integer;
    now_riyadh timestamptz;
    existing_spin gift_wheel_spins%ROWTYPE;
    eligible_rewards gift_wheel_rewards[];
    reward_row gift_wheel_rewards%ROWTYPE;
    total_weight integer;
    random_val integer;
    cumulative integer;
    coupon_code_val text;
    new_coupon_id uuid;
    computed_expiry date;
BEGIN
    -- Get settings
    SELECT * INTO settings_row FROM gift_wheel_settings LIMIT 1;

    IF settings_row IS NULL OR NOT settings_row.active THEN
        RETURN jsonb_build_object('success', false, 'error', 'Gift Wheel is not active');
    END IF;

    now_riyadh := now() AT TIME ZONE settings_row.timezone;

    -- Validate bill date = today
    IF p_bill_date IS NOT NULL AND p_bill_date != to_char(now_riyadh, 'YYYY-MM-DD') THEN
        RETURN jsonb_build_object('success', false, 'error', 'Your chance has expired', 'error_code', 'bill_date_expired');
    END IF;

    -- Check scheduled time
    IF settings_row.start_datetime IS NOT NULL AND now() < settings_row.start_datetime THEN
        RETURN jsonb_build_object('success', false, 'error', 'Gift Wheel has not started yet');
    END IF;

    IF settings_row.end_datetime IS NOT NULL AND now() > settings_row.end_datetime THEN
        RETURN jsonb_build_object('success', false, 'error', 'Gift Wheel has ended');
    END IF;

    -- Check daily limit
    SELECT count(*) INTO spins_today
    FROM gift_wheel_spins
    WHERE (created_at AT TIME ZONE settings_row.timezone)::date = now_riyadh::date
      AND rejected = false;

    IF spins_today >= settings_row.daily_limit THEN
        RETURN jsonb_build_object('success', false, 'error', 'Daily limit reached. Please try again tomorrow');
    END IF;

    -- Check duplicate bill with same amount
    SELECT * INTO existing_spin FROM gift_wheel_spins WHERE bill_number = p_bill_number AND bill_amount = p_bill_amount AND rejected = false LIMIT 1;
    IF existing_spin.id IS NOT NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'This bill with the same amount has already been used');
    END IF;

    -- Get eligible rewards based on bill amount
    SELECT array_agg(r) INTO eligible_rewards
    FROM gift_wheel_rewards r
    WHERE r.active = true
      AND r.min_bill <= p_bill_amount
      AND (r.usage_limit IS NULL OR r.usage_count < r.usage_limit);

    IF eligible_rewards IS NULL OR array_length(eligible_rewards, 1) IS NULL THEN
        -- No rewards available, record rejected spin
        INSERT INTO gift_wheel_spins (bill_number, bill_amount, bill_date, bill_image_url, rejected, reject_reason)
        VALUES (p_bill_number, p_bill_amount, p_bill_date, p_bill_image_url, true, 'No eligible rewards');

        RETURN jsonb_build_object('success', false, 'error', 'No rewards available at this time');
    END IF;

    -- Calculate total weight
    total_weight := 0;
    FOREACH reward_row IN ARRAY eligible_rewards LOOP
        total_weight := total_weight + reward_row.weight;
    END LOOP;

    -- Weighted random selection
    random_val := floor(random() * total_weight)::integer;
    cumulative := 0;
    reward_row := eligible_rewards[1]; -- default fallback

    FOREACH reward_row IN ARRAY eligible_rewards LOOP
        cumulative := cumulative + reward_row.weight;
        IF random_val < cumulative THEN
            EXIT;
        END IF;
    END LOOP;

    -- Generate coupon code for winning spins
    IF reward_row.reward_type != 'no_reward' THEN
        LOOP
            coupon_code_val := lpad((floor(random() * 900000) + 100000)::text, 6, '0');
            EXIT WHEN NOT EXISTS (SELECT 1 FROM gift_wheel_coupons WHERE code = coupon_code_val);
        END LOOP;

        -- Compute expiry from validity_days
        computed_expiry := (CURRENT_DATE + (reward_row.validity_days || ' days')::interval)::date;

        INSERT INTO gift_wheel_coupons (code, reward_id, reward_label, reward_label_en, reward_label_ar, reward_type, reward_value, max_discount, expiry_date, status, bill_number, bill_amount, bill_date)
        VALUES (
            coupon_code_val,
            reward_row.id,
            COALESCE(reward_row.reward_label_en, reward_row.label),
            reward_row.reward_label_en,
            reward_row.reward_label_ar,
            reward_row.reward_type,
            reward_row.value,
            reward_row.max_discount,
            computed_expiry,
            'active',
            p_bill_number,
            p_bill_amount,
            p_bill_date
        )
        RETURNING id INTO new_coupon_id;

        -- Update usage count
        UPDATE gift_wheel_rewards SET usage_count = usage_count + 1, updated_at = now() WHERE id = reward_row.id;

        -- Record winning spin
        INSERT INTO gift_wheel_spins (bill_number, bill_amount, bill_date, bill_image_url, reward_id, reward_label, coupon_code, is_winner)
        VALUES (p_bill_number, p_bill_amount, p_bill_date, p_bill_image_url, reward_row.id, COALESCE(reward_row.reward_label_en, reward_row.label), coupon_code_val, true);

        RETURN jsonb_build_object(
            'success', true,
            'is_winner', true,
            'reward_label', COALESCE(reward_row.reward_label_en, reward_row.label),
            'reward_label_en', reward_row.reward_label_en,
            'reward_label_ar', reward_row.reward_label_ar,
            'reward_type', reward_row.reward_type,
            'reward_value', reward_row.value,
            'max_discount', reward_row.max_discount,
            'coupon_code', coupon_code_val,
            'expiry_date', computed_expiry,
            'validity_days', reward_row.validity_days
        );
    ELSE
        -- No reward (better luck next time)
        INSERT INTO gift_wheel_spins (bill_number, bill_amount, bill_date, bill_image_url, reward_id, reward_label, is_winner)
        VALUES (p_bill_number, p_bill_amount, p_bill_date, p_bill_image_url, reward_row.id, COALESCE(reward_row.reward_label_en, reward_row.label), false);

        RETURN jsonb_build_object(
            'success', true,
            'is_winner', false,
            'reward_label', COALESCE(reward_row.reward_label_en, reward_row.label),
            'reward_label_en', reward_row.reward_label_en,
            'reward_label_ar', reward_row.reward_label_ar
        );
    END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.gift_wheel_spin(text, numeric, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.gift_wheel_spin(text, numeric, text, text) TO anon;

-- ============================================================
-- 7. RPC: VALIDATE COUPON (for cashier)
-- ============================================================
CREATE OR REPLACE FUNCTION public.gift_wheel_validate_coupon(p_code text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    coupon_row gift_wheel_coupons%ROWTYPE;
BEGIN
    SELECT * INTO coupon_row FROM gift_wheel_coupons WHERE code = trim(p_code);

    IF coupon_row.id IS NULL THEN
        RETURN jsonb_build_object('valid', false, 'error', 'Coupon not found');
    END IF;

    IF coupon_row.status = 'redeemed' THEN
        RETURN jsonb_build_object('valid', false, 'error', 'Coupon already redeemed');
    END IF;

    IF coupon_row.status = 'expired' OR (coupon_row.expiry_date IS NOT NULL AND coupon_row.expiry_date < CURRENT_DATE) THEN
        RETURN jsonb_build_object('valid', false, 'error', 'Coupon has expired');
    END IF;

    IF coupon_row.status = 'cancelled' THEN
        RETURN jsonb_build_object('valid', false, 'error', 'Coupon has been cancelled');
    END IF;

    RETURN jsonb_build_object(
        'valid', true,
        'code', coupon_row.code,
        'reward_label', coupon_row.reward_label,
        'reward_label_en', coupon_row.reward_label_en,
        'reward_label_ar', coupon_row.reward_label_ar,
        'reward_type', coupon_row.reward_type,
        'reward_value', coupon_row.reward_value,
        'max_discount', coupon_row.max_discount,
        'expiry_date', coupon_row.expiry_date,
        'status', coupon_row.status,
        'branch_id', coupon_row.branch_id,
        'bill_number', coupon_row.bill_number,
        'bill_amount', coupon_row.bill_amount,
        'bill_date', coupon_row.bill_date
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.gift_wheel_validate_coupon(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.gift_wheel_validate_coupon(text) TO anon;

-- ============================================================
-- 8. RPC: REDEEM COUPON (cashier marks as printed/redeemed)
-- ============================================================
CREATE OR REPLACE FUNCTION public.gift_wheel_redeem_coupon(p_code text, p_action text DEFAULT 'print', p_branch_id text DEFAULT NULL, p_redeemed_bill_number text DEFAULT NULL, p_redeemed_amount numeric DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    coupon_row gift_wheel_coupons%ROWTYPE;
BEGIN
    SELECT * INTO coupon_row FROM gift_wheel_coupons WHERE code = trim(p_code);

    IF coupon_row.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Coupon not found');
    END IF;

    IF coupon_row.status = 'redeemed' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Coupon already redeemed');
    END IF;

    IF coupon_row.expiry_date IS NOT NULL AND coupon_row.expiry_date < CURRENT_DATE THEN
        UPDATE gift_wheel_coupons SET status = 'expired' WHERE id = coupon_row.id;
        RETURN jsonb_build_object('success', false, 'error', 'Coupon has expired');
    END IF;

    IF p_action = 'print' THEN
        UPDATE gift_wheel_coupons SET status = 'printed', printed_at = now(), branch_id = p_branch_id WHERE id = coupon_row.id;
        RETURN jsonb_build_object('success', true, 'action', 'printed');
    ELSIF p_action = 'redeem' THEN
        UPDATE gift_wheel_coupons SET status = 'redeemed', redeemed_at = now(), redeemed_bill_number = p_redeemed_bill_number, redeemed_amount = p_redeemed_amount, branch_id = COALESCE(p_branch_id, branch_id) WHERE id = coupon_row.id;
        RETURN jsonb_build_object('success', true, 'action', 'redeemed');
    ELSE
        RETURN jsonb_build_object('success', false, 'error', 'Invalid action');
    END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.gift_wheel_redeem_coupon(text, text, text, text, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.gift_wheel_redeem_coupon(text, text, text, text, numeric) TO anon;

-- ============================================================
-- 9. RPC: DASHBOARD STATS
-- ============================================================
CREATE OR REPLACE FUNCTION public.gift_wheel_dashboard_stats(
    p_from date DEFAULT NULL,
    p_to date DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    from_date date;
    to_date date;
    result jsonb;
    daily_data jsonb;
    reward_dist jsonb;
BEGIN
    from_date := COALESCE(p_from, CURRENT_DATE);
    to_date := COALESCE(p_to, CURRENT_DATE);

    SELECT jsonb_build_object(
        'total_spins', count(*) FILTER (WHERE rejected = false),
        'total_spins_today', count(*) FILTER (WHERE rejected = false AND (created_at AT TIME ZONE 'Asia/Riyadh')::date = CURRENT_DATE),
        'unique_bills', count(DISTINCT bill_number) FILTER (WHERE rejected = false),
        'winning_spins', count(*) FILTER (WHERE is_winner = true AND rejected = false),
        'losing_spins', count(*) FILTER (WHERE is_winner = false AND rejected = false),
        'rejected_bills', count(*) FILTER (WHERE rejected = true)
    ) INTO result
    FROM gift_wheel_spins
    WHERE (created_at AT TIME ZONE 'Asia/Riyadh')::date BETWEEN from_date AND to_date;

    -- Coupon stats
    SELECT result || jsonb_build_object(
        'coupons_printed', count(*) FILTER (WHERE printed_at IS NOT NULL),
        'coupons_redeemed', count(*) FILTER (WHERE redeemed_at IS NOT NULL),
        'coupons_active', count(*) FILTER (WHERE status = 'active'),
        'coupons_expired', count(*) FILTER (WHERE status = 'expired')
    ) INTO result
    FROM gift_wheel_coupons
    WHERE created_at::date BETWEEN from_date AND to_date;

    -- Reward distribution
    SELECT COALESCE(jsonb_agg(row_data), '[]'::jsonb) INTO reward_dist
    FROM (
        SELECT jsonb_build_object(
            'label', reward_label,
            'count', count(*)
        ) as row_data
        FROM gift_wheel_spins
        WHERE rejected = false
          AND (created_at AT TIME ZONE 'Asia/Riyadh')::date BETWEEN from_date AND to_date
        GROUP BY reward_label
        ORDER BY count(*) DESC
    ) sub;

    result := result || jsonb_build_object('reward_distribution', reward_dist);

    -- Spins by date
    SELECT COALESCE(jsonb_agg(row_data ORDER BY d), '[]'::jsonb) INTO daily_data
    FROM (
        SELECT jsonb_build_object(
            'date', (created_at AT TIME ZONE 'Asia/Riyadh')::date,
            'spins', count(*)
        ) as row_data,
        (created_at AT TIME ZONE 'Asia/Riyadh')::date as d
        FROM gift_wheel_spins
        WHERE rejected = false
          AND (created_at AT TIME ZONE 'Asia/Riyadh')::date BETWEEN from_date AND to_date
        GROUP BY (created_at AT TIME ZONE 'Asia/Riyadh')::date
    ) sub;

    result := result || jsonb_build_object('spins_by_date', daily_data);

    RETURN result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.gift_wheel_dashboard_stats(date, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.gift_wheel_dashboard_stats(date, date) TO anon;

-- ============================================================
-- 7. TABLE-LEVEL GRANTS
-- ============================================================
GRANT SELECT, INSERT, UPDATE, DELETE ON public.gift_wheel_settings TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.gift_wheel_rewards TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.gift_wheel_coupons TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.gift_wheel_spins TO authenticated;

GRANT ALL ON public.gift_wheel_settings TO anon;
GRANT ALL ON public.gift_wheel_rewards TO anon;
GRANT ALL ON public.gift_wheel_coupons TO anon;
GRANT ALL ON public.gift_wheel_spins TO anon;
