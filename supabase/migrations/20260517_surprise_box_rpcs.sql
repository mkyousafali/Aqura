-- ============================================================
-- Surprise Box: RPC Functions
-- ============================================================

-- 1. Check if Surprise Box is active
CREATE OR REPLACE FUNCTION public.surprise_box_check_status()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_settings RECORD;
    v_now timestamptz := now() AT TIME ZONE 'UTC';
    v_today_count integer;
BEGIN
    SELECT * INTO v_settings FROM public.surprise_box_settings LIMIT 1;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('active', false, 'reason', 'not_configured');
    END IF;
    IF NOT v_settings.active THEN
        RETURN jsonb_build_object('active', false, 'reason', 'disabled');
    END IF;
    IF v_settings.start_datetime IS NOT NULL AND v_now < v_settings.start_datetime THEN
        RETURN jsonb_build_object('active', false, 'reason', 'not_started');
    END IF;
    IF v_settings.end_datetime IS NOT NULL AND v_now > v_settings.end_datetime THEN
        RETURN jsonb_build_object('active', false, 'reason', 'ended');
    END IF;
    -- Daily limit check
    SELECT COUNT(*) INTO v_today_count
    FROM public.surprise_box_plays
    WHERE created_at >= (now() AT TIME ZONE v_settings.timezone)::date
      AND rejected = false;
    IF v_today_count >= v_settings.daily_limit THEN
        RETURN jsonb_build_object('active', false, 'reason', 'daily_limit_reached');
    END IF;
    RETURN jsonb_build_object(
        'active', true,
        'minimum_bill_amount', v_settings.minimum_bill_amount,
        'box_count', v_settings.box_count,
        'enforce_bill_date', v_settings.enforce_bill_date,
        'terms_en', v_settings.terms_en,
        'terms_ar', v_settings.terms_ar,
        'daily_remaining', v_settings.daily_limit - v_today_count
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.surprise_box_check_status() TO authenticated;
GRANT EXECUTE ON FUNCTION public.surprise_box_check_status() TO anon;


-- 2. Validate bill (pre-check before play)
CREATE OR REPLACE FUNCTION public.surprise_box_validate_bill(
    p_bill_number text,
    p_bill_amount numeric,
    p_bill_date text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_settings RECORD;
    v_existing RECORD;
BEGIN
    SELECT * INTO v_settings FROM public.surprise_box_settings LIMIT 1;
    IF NOT FOUND OR NOT v_settings.active THEN
        RETURN jsonb_build_object('valid', false, 'reason', 'campaign_inactive');
    END IF;
    -- Minimum bill amount
    IF p_bill_amount < v_settings.minimum_bill_amount THEN
        RETURN jsonb_build_object(
            'valid', false,
            'reason', 'below_minimum',
            'minimum', v_settings.minimum_bill_amount
        );
    END IF;
    -- Bill already used
    SELECT id INTO v_existing
    FROM public.surprise_box_plays
    WHERE bill_number = p_bill_number
      AND rejected = false
    LIMIT 1;
    IF FOUND THEN
        RETURN jsonb_build_object('valid', false, 'reason', 'already_played');
    END IF;
    RETURN jsonb_build_object('valid', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.surprise_box_validate_bill(text, numeric, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.surprise_box_validate_bill(text, numeric, text) TO anon;


-- 3. Core play function (concurrency-safe, server-side weighted random)
CREATE OR REPLACE FUNCTION public.surprise_box_play(
    p_bill_number text,
    p_bill_amount numeric,
    p_bill_image_url text DEFAULT NULL,
    p_bill_date text DEFAULT NULL,
    p_box_selected integer DEFAULT NULL,
    p_manual_entry boolean DEFAULT false,
    p_manual_entry_by uuid DEFAULT NULL,
    p_manual_entry_username text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_settings RECORD;
    v_now timestamptz := now() AT TIME ZONE 'UTC';
    v_today_count integer;
    v_existing RECORD;
    v_reward RECORD;
    v_voucher_code text;
    v_play_id uuid;
    v_voucher_id uuid;
    v_expires_at date;
    v_total_weight bigint;
    v_rand_val bigint;
    v_cumulative bigint := 0;
BEGIN
    -- Lock settings row to prevent concurrent races
    SELECT * INTO v_settings FROM public.surprise_box_settings LIMIT 1 FOR UPDATE;
    IF NOT FOUND OR NOT v_settings.active THEN
        RETURN jsonb_build_object('success', false, 'reason', 'campaign_inactive');
    END IF;
    -- Date window
    IF v_settings.start_datetime IS NOT NULL AND v_now < v_settings.start_datetime THEN
        RETURN jsonb_build_object('success', false, 'reason', 'not_started');
    END IF;
    IF v_settings.end_datetime IS NOT NULL AND v_now > v_settings.end_datetime THEN
        RETURN jsonb_build_object('success', false, 'reason', 'ended');
    END IF;
    -- Daily limit
    SELECT COUNT(*) INTO v_today_count
    FROM public.surprise_box_plays
    WHERE created_at >= (now() AT TIME ZONE v_settings.timezone)::date
      AND rejected = false;
    IF v_today_count >= v_settings.daily_limit THEN
        RETURN jsonb_build_object('success', false, 'reason', 'daily_limit_reached');
    END IF;
    -- Minimum bill amount
    IF p_bill_amount < v_settings.minimum_bill_amount THEN
        RETURN jsonb_build_object('success', false, 'reason', 'below_minimum');
    END IF;
    -- Bill already played
    SELECT id INTO v_existing
    FROM public.surprise_box_plays
    WHERE bill_number = p_bill_number AND rejected = false
    LIMIT 1;
    IF FOUND THEN
        RETURN jsonb_build_object('success', false, 'reason', 'already_played');
    END IF;

    -- Weighted random reward selection
    SELECT SUM(weight) INTO v_total_weight
    FROM public.surprise_box_rewards
    WHERE active = true
      AND (max_count IS NULL OR issued_count < max_count);

    IF v_total_weight IS NULL OR v_total_weight = 0 THEN
        -- No rewards available — insert rejected play
        INSERT INTO public.surprise_box_plays (bill_number, bill_amount, bill_date, bill_image_url,
            rejected, reject_reason, box_selected, manual_entry, manual_entry_by, manual_entry_username)
        VALUES (p_bill_number, p_bill_amount, p_bill_date, p_bill_image_url,
            true, 'no_rewards_available', p_box_selected, p_manual_entry, p_manual_entry_by, p_manual_entry_username);
        RETURN jsonb_build_object('success', false, 'reason', 'no_rewards_available');
    END IF;

    v_rand_val := floor(random() * v_total_weight)::bigint;

    FOR v_reward IN
        SELECT * FROM public.surprise_box_rewards
        WHERE active = true
          AND (max_count IS NULL OR issued_count < max_count)
        ORDER BY id
    LOOP
        v_cumulative := v_cumulative + v_reward.weight;
        IF v_rand_val < v_cumulative THEN
            EXIT;
        END IF;
    END LOOP;

    -- Generate unique voucher code (retry up to 5 times on collision)
    FOR i IN 1..5 LOOP
        v_voucher_code := upper(encode(gen_random_bytes(6), 'hex'));
        EXIT WHEN NOT EXISTS (SELECT 1 FROM public.surprise_box_vouchers WHERE code = v_voucher_code);
    END LOOP;

    v_expires_at := (now() + (v_reward.expiry_days || ' days')::interval)::date;

    -- Insert play record
    INSERT INTO public.surprise_box_plays (
        bill_number, bill_amount, bill_date, bill_image_url,
        reward_id, voucher_code,
        is_winner, rejected,
        box_selected, manual_entry, manual_entry_by, manual_entry_username
    )
    VALUES (
        p_bill_number, p_bill_amount, p_bill_date, p_bill_image_url,
        CASE WHEN v_reward.is_no_win THEN NULL ELSE v_reward.id END,
        CASE WHEN v_reward.is_no_win THEN NULL ELSE v_voucher_code END,
        NOT v_reward.is_no_win, false,
        p_box_selected, p_manual_entry, p_manual_entry_by, p_manual_entry_username
    )
    RETURNING id INTO v_play_id;

    -- If winning reward, issue voucher
    IF NOT v_reward.is_no_win THEN
        INSERT INTO public.surprise_box_vouchers (
            code, play_id, reward_id, voucher_value,
            label_en, label_ar, expires_at, bill_number, bill_amount
        )
        VALUES (
            v_voucher_code, v_play_id, v_reward.id, v_reward.voucher_value,
            v_reward.label_en, v_reward.label_ar, v_expires_at, p_bill_number, p_bill_amount
        )
        RETURNING id INTO v_voucher_id;

        -- Increment issued_count
        UPDATE public.surprise_box_rewards
        SET issued_count = issued_count + 1
        WHERE id = v_reward.id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'is_winner', NOT v_reward.is_no_win,
        'play_id', v_play_id,
        'reward', jsonb_build_object(
            'id', v_reward.id,
            'label_en', v_reward.label_en,
            'label_ar', v_reward.label_ar,
            'voucher_value', v_reward.voucher_value,
            'is_no_win', v_reward.is_no_win,
            'expiry_days', v_reward.expiry_days
        ),
        'voucher_code', v_voucher_code,
        'expires_at', v_expires_at
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.surprise_box_play(text, numeric, text, text, integer, boolean, uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.surprise_box_play(text, numeric, text, text, integer, boolean, uuid, text) TO anon;


-- 4. Validate voucher (cashier)
CREATE OR REPLACE FUNCTION public.surprise_box_validate_voucher(p_code text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_voucher RECORD;
BEGIN
    -- Expire overdue vouchers first
    UPDATE public.surprise_box_vouchers
    SET status = 'expired'
    WHERE status = 'active' AND expires_at < now()::date;

    SELECT v.*, r.label_en, r.label_ar
    INTO v_voucher
    FROM public.surprise_box_vouchers v
    LEFT JOIN public.surprise_box_rewards r ON r.id = v.reward_id
    WHERE v.code = upper(trim(p_code));

    IF NOT FOUND THEN
        RETURN jsonb_build_object('valid', false, 'reason', 'not_found');
    END IF;
    IF v_voucher.status = 'redeemed' THEN
        RETURN jsonb_build_object('valid', false, 'reason', 'already_redeemed', 'redeemed_at', v_voucher.redeemed_at);
    END IF;
    IF v_voucher.status = 'expired' OR v_voucher.expires_at < now()::date THEN
        RETURN jsonb_build_object('valid', false, 'reason', 'expired');
    END IF;
    IF v_voucher.status = 'cancelled' THEN
        RETURN jsonb_build_object('valid', false, 'reason', 'cancelled');
    END IF;
    RETURN jsonb_build_object(
        'valid', true,
        'voucher_id', v_voucher.id,
        'voucher_value', v_voucher.voucher_value,
        'label_en', v_voucher.label_en,
        'label_ar', v_voucher.label_ar,
        'expires_at', v_voucher.expires_at,
        'bill_number', v_voucher.bill_number,
        'bill_amount', v_voucher.bill_amount,
        'issued_at', v_voucher.issued_at
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.surprise_box_validate_voucher(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.surprise_box_validate_voucher(text) TO anon;


-- 5. Redeem voucher (cashier)
CREATE OR REPLACE FUNCTION public.surprise_box_redeem_voucher(
    p_code text,
    p_redeemed_bill_number text DEFAULT NULL,
    p_redeemed_amount numeric DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_voucher RECORD;
BEGIN
    SELECT * INTO v_voucher
    FROM public.surprise_box_vouchers
    WHERE code = upper(trim(p_code))
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'reason', 'not_found');
    END IF;
    IF v_voucher.status != 'active' THEN
        RETURN jsonb_build_object('success', false, 'reason', v_voucher.status);
    END IF;
    IF v_voucher.expires_at < now()::date THEN
        UPDATE public.surprise_box_vouchers SET status = 'expired' WHERE id = v_voucher.id;
        RETURN jsonb_build_object('success', false, 'reason', 'expired');
    END IF;

    UPDATE public.surprise_box_vouchers
    SET status = 'redeemed',
        redeemed_at = now(),
        redeemed_bill_number = p_redeemed_bill_number,
        redeemed_amount = p_redeemed_amount
    WHERE id = v_voucher.id;

    RETURN jsonb_build_object(
        'success', true,
        'voucher_value', v_voucher.voucher_value,
        'label_en', v_voucher.label_en,
        'label_ar', v_voucher.label_ar
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.surprise_box_redeem_voucher(text, text, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.surprise_box_redeem_voucher(text, text, numeric) TO anon;


-- 6. Dashboard stats
CREATE OR REPLACE FUNCTION public.surprise_box_dashboard_stats(
    p_from timestamptz DEFAULT now() - interval '30 days',
    p_to   timestamptz DEFAULT now()
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_result jsonb;
BEGIN
    SELECT jsonb_build_object(
        'total_plays',       COUNT(*) FILTER (WHERE rejected = false),
        'total_winners',     COUNT(*) FILTER (WHERE is_winner = true),
        'total_rejected',    COUNT(*) FILTER (WHERE rejected = true),
        'total_voucher_value', COALESCE(SUM(v.voucher_value) FILTER (WHERE p.is_winner = true), 0),
        'total_redeemed',    COUNT(*) FILTER (WHERE v.status = 'redeemed'),
        'total_redeemed_value', COALESCE(SUM(v.voucher_value) FILTER (WHERE v.status = 'redeemed'), 0),
        'redemption_rate',   ROUND(
            CASE WHEN COUNT(*) FILTER (WHERE p.is_winner = true) > 0
                 THEN COUNT(*) FILTER (WHERE v.status = 'redeemed')::numeric
                    / COUNT(*) FILTER (WHERE p.is_winner = true) * 100
                 ELSE 0
            END, 1)
    )
    INTO v_result
    FROM public.surprise_box_plays p
    LEFT JOIN public.surprise_box_vouchers v ON v.play_id = p.id
    WHERE p.created_at BETWEEN p_from AND p_to;

    RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.surprise_box_dashboard_stats(timestamptz, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.surprise_box_dashboard_stats(timestamptz, timestamptz) TO anon;
