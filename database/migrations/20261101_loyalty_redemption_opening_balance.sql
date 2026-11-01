-- Opening-balance points are redeemable, just like earned points.
-- Preserve the opening balance when confirmation updates the remaining balance.
BEGIN;

CREATE OR REPLACE FUNCTION public.initiate_loyalty_redemption(p_phone text, p_points_to_redeem numeric, p_redemption_type text, p_cashier_id text DEFAULT NULL::text, p_branch_id text DEFAULT NULL::text, p_erp_branch_id text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_normalized  text;
    v_customer    record;
    v_tier        record;
    v_available   numeric(14,2);
    v_otp         text;
    v_coupon_code text;
    v_redemp_id   uuid;
BEGIN
    v_normalized := regexp_replace(p_phone, '\D', '', 'g');
    IF v_normalized LIKE '0%' THEN
        v_normalized := '966' || substring(v_normalized FROM 2);
    ELSIF NOT v_normalized LIKE '966%' THEN
        v_normalized := '966' || v_normalized;
    END IF;

    SELECT id, name, whatsapp_number,
           COALESCE(total_points_earned, 0) AS total_points_earned,
           COALESCE(total_redemptions, 0)   AS total_redemptions,
           COALESCE(loyalty_program_opening_balance, 0) AS opening_balance,
           loyalty_tier_id, registration_status
    INTO v_customer
    FROM public.customers
    WHERE whatsapp_number = v_normalized AND is_deleted = false
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'customer_not_found');
    END IF;

    IF v_customer.registration_status != 'approved' THEN
        RETURN jsonb_build_object('success', false, 'error', 'customer_not_approved');
    END IF;

    v_available := v_customer.total_points_earned - v_customer.total_redemptions + v_customer.opening_balance;

    SELECT COALESCE(min_redeem_points, 0) AS min_redeem_points
    INTO v_tier
    FROM public.loyalty_tiers
    WHERE id = v_customer.loyalty_tier_id
    LIMIT 1;

    IF v_available <= 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'no_points_available');
    END IF;

    IF v_available < COALESCE(v_tier.min_redeem_points, 0) THEN
        RETURN jsonb_build_object('success', false, 'error', 'below_minimum',
            'min_required', COALESCE(v_tier.min_redeem_points, 0),
            'available', v_available);
    END IF;

    IF p_points_to_redeem > v_available THEN
        RETURN jsonb_build_object('success', false, 'error', 'exceeds_available',
            'available', v_available);
    END IF;

    IF p_points_to_redeem <= 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'invalid_points_amount');
    END IF;

    -- Expire any existing pending redemption for this customer
    UPDATE public.loyalty_redemptions
    SET status = 'expired'
    WHERE customer_id = v_customer.id AND status = 'pending';

    -- Generate 6-digit OTP
    v_otp := lpad((floor(random() * 900000 + 100000)::int)::text, 6, '0');

    -- Generate unique coupon code
    v_coupon_code := 'LYL-' || upper(substring(md5(random()::text || clock_timestamp()::text) FROM 1 FOR 8));

    INSERT INTO public.loyalty_redemptions (
        customer_id, whatsapp_number, points_redeemed, coupon_code, coupon_value,
        redemption_type, status, otp_code, otp_sent_at,
        cashier_id, branch_id, erp_branch_id
    ) VALUES (
        v_customer.id, v_customer.whatsapp_number,
        p_points_to_redeem, v_coupon_code, p_points_to_redeem,
        p_redemption_type, 'pending', v_otp, now(),
        p_cashier_id, p_branch_id, p_erp_branch_id
    ) RETURNING id INTO v_redemp_id;

    RETURN jsonb_build_object(
        'success',          true,
        'redemption_id',    v_redemp_id,
        'otp_code',         v_otp,
        'coupon_code',      v_coupon_code,
        'points_to_redeem', p_points_to_redeem,
        'coupon_value',     p_points_to_redeem,
        'whatsapp_number',  v_customer.whatsapp_number,
        'customer_name',    v_customer.name
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.confirm_loyalty_redemption(p_redemption_id uuid, p_otp_code text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_redemp   record;
BEGIN
    SELECT * INTO v_redemp
    FROM public.loyalty_redemptions
    WHERE id = p_redemption_id
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'redemption_not_found');
    END IF;

    IF v_redemp.status != 'pending' THEN
        RETURN jsonb_build_object('success', false, 'error', 'redemption_not_pending',
            'status', v_redemp.status);
    END IF;

    -- Check OTP expiry (10 minutes)
    IF now() - v_redemp.otp_sent_at > interval '10 minutes' THEN
        UPDATE public.loyalty_redemptions SET status = 'expired' WHERE id = p_redemption_id;
        RETURN jsonb_build_object('success', false, 'error', 'otp_expired');
    END IF;

    -- Validate OTP
    IF v_redemp.otp_code != p_otp_code THEN
        -- Increment attempts
        UPDATE public.loyalty_redemptions
        SET otp_attempts = otp_attempts + 1
        WHERE id = p_redemption_id;

        -- Lock after 5 failed attempts
        IF v_redemp.otp_attempts + 1 >= 5 THEN
            UPDATE public.loyalty_redemptions SET status = 'cancelled' WHERE id = p_redemption_id;
            RETURN jsonb_build_object('success', false, 'error', 'max_otp_attempts');
        END IF;

        RETURN jsonb_build_object('success', false, 'error', 'invalid_otp',
            'attempts_remaining', 5 - (v_redemp.otp_attempts + 1));
    END IF;

    -- OTP valid — confirm and update balances atomically
    UPDATE public.loyalty_redemptions
    SET status = 'confirmed', otp_confirmed_at = now(), confirmed_at = now()
    WHERE id = p_redemption_id;

    UPDATE public.customers
    SET
        total_redemptions           = COALESCE(total_redemptions, 0) + v_redemp.points_redeemed,
        final_loyalty_point_balance = COALESCE(total_points_earned, 0)
                                      + COALESCE(loyalty_program_opening_balance, 0)
                                      - (COALESCE(total_redemptions, 0) + v_redemp.points_redeemed),
        updated_at                  = now()
    WHERE id = v_redemp.customer_id;

    RETURN jsonb_build_object(
        'success',         true,
        'coupon_code',     v_redemp.coupon_code,
        'coupon_value',    v_redemp.coupon_value,
        'points_redeemed', v_redemp.points_redeemed,
        'customer_id',     v_redemp.customer_id
    );
END;
$$;

COMMIT;
