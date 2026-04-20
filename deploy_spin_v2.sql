DROP FUNCTION IF EXISTS public.gift_wheel_spin(text, numeric, text, text);

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
    SELECT * INTO settings_row FROM gift_wheel_settings LIMIT 1;

    IF settings_row IS NULL OR NOT settings_row.active THEN
        RETURN jsonb_build_object('success', false, 'error', 'Gift Wheel is not active');
    END IF;

    now_riyadh := now() AT TIME ZONE settings_row.timezone;

    IF p_bill_date IS NOT NULL AND p_bill_date != to_char(now_riyadh, 'YYYY-MM-DD') THEN
        RETURN jsonb_build_object('success', false, 'error', 'Your chance has expired', 'error_code', 'bill_date_expired');
    END IF;

    IF settings_row.start_datetime IS NOT NULL AND now() < settings_row.start_datetime THEN
        RETURN jsonb_build_object('success', false, 'error', 'Gift Wheel has not started yet');
    END IF;

    IF settings_row.end_datetime IS NOT NULL AND now() > settings_row.end_datetime THEN
        RETURN jsonb_build_object('success', false, 'error', 'Gift Wheel has ended');
    END IF;

    SELECT count(*) INTO spins_today
    FROM gift_wheel_spins
    WHERE (created_at AT TIME ZONE settings_row.timezone)::date = now_riyadh::date
      AND rejected = false;

    IF spins_today >= settings_row.daily_limit THEN
        RETURN jsonb_build_object('success', false, 'error', 'Daily limit reached. Please try again tomorrow');
    END IF;

    SELECT * INTO existing_spin FROM gift_wheel_spins WHERE bill_number = p_bill_number AND bill_amount = p_bill_amount AND rejected = false LIMIT 1;
    IF existing_spin.id IS NOT NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'This bill with the same amount has already been used');
    END IF;

    SELECT array_agg(r) INTO eligible_rewards
    FROM gift_wheel_rewards r
    WHERE r.active = true
      AND r.min_bill <= p_bill_amount
      AND (r.usage_limit IS NULL OR r.usage_count < r.usage_limit);

    IF eligible_rewards IS NULL OR array_length(eligible_rewards, 1) IS NULL THEN
        INSERT INTO gift_wheel_spins (bill_number, bill_amount, bill_date, bill_image_url, rejected, reject_reason)
        VALUES (p_bill_number, p_bill_amount, p_bill_date, p_bill_image_url, true, 'No eligible rewards');
        RETURN jsonb_build_object('success', false, 'error', 'No rewards available at this time');
    END IF;

    total_weight := 0;
    FOREACH reward_row IN ARRAY eligible_rewards LOOP
        total_weight := total_weight + reward_row.weight;
    END LOOP;

    random_val := floor(random() * total_weight)::integer;
    cumulative := 0;
    reward_row := eligible_rewards[1];

    FOREACH reward_row IN ARRAY eligible_rewards LOOP
        cumulative := cumulative + reward_row.weight;
        IF random_val < cumulative THEN
            EXIT;
        END IF;
    END LOOP;

    IF reward_row.reward_type != 'no_reward' THEN
        LOOP
            coupon_code_val := lpad((floor(random() * 900000) + 100000)::text, 6, '0');
            EXIT WHEN NOT EXISTS (SELECT 1 FROM gift_wheel_coupons WHERE code = coupon_code_val);
        END LOOP;

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

        UPDATE gift_wheel_rewards SET usage_count = usage_count + 1, updated_at = now() WHERE id = reward_row.id;

        INSERT INTO gift_wheel_spins (bill_number, bill_amount, bill_date, bill_image_url, reward_id, reward_label, reward_label_ar, reward_label_en, coupon_code, is_winner)
        VALUES (p_bill_number, p_bill_amount, p_bill_date, p_bill_image_url, reward_row.id, COALESCE(reward_row.reward_label_en, reward_row.label), reward_row.reward_label_ar, reward_row.reward_label_en, coupon_code_val, true);

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
        INSERT INTO gift_wheel_spins (bill_number, bill_amount, bill_date, bill_image_url, reward_id, reward_label, reward_label_ar, reward_label_en, is_winner)
        VALUES (p_bill_number, p_bill_amount, p_bill_date, p_bill_image_url, reward_row.id, COALESCE(reward_row.reward_label_en, reward_row.label), reward_row.reward_label_ar, reward_row.reward_label_en, false);

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
