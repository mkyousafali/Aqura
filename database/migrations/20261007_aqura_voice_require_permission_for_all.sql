BEGIN;

CREATE OR REPLACE FUNCTION public.consume_aqura_voice_usage(p_user_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_access public.aqura_voice_access%ROWTYPE; v_used integer; v_today date;
BEGIN
  PERFORM 1 FROM public.users WHERE id=p_user_id AND status='active';
  IF NOT FOUND THEN RETURN jsonb_build_object('success',false,'error','User account is inactive'); END IF;
  SELECT * INTO v_access FROM public.aqura_voice_access WHERE user_id=p_user_id;
  IF NOT FOUND OR NOT v_access.is_enabled THEN RETURN jsonb_build_object('success',false,'error','You do not have permission to use Aqura Voice'); END IF;
  v_today := (now() AT TIME ZONE 'Asia/Riyadh')::date;
  IF v_access.subscription_expiry IS NOT NULL AND v_access.subscription_expiry < v_today THEN
    RETURN jsonb_build_object('success',false,'error','Your Aqura Voice subscription has expired');
  END IF;
  INSERT INTO public.aqura_voice_daily_usage(user_id,usage_date,usage_count) VALUES(p_user_id,v_today,1)
  ON CONFLICT(user_id,usage_date) DO UPDATE SET usage_count=aqura_voice_daily_usage.usage_count+1,updated_at=now()
  WHERE aqura_voice_daily_usage.usage_count < v_access.daily_limit
  RETURNING usage_count INTO v_used;
  IF v_used IS NULL THEN RETURN jsonb_build_object('success',false,'error','Daily Aqura Voice usage limit reached'); END IF;
  RETURN jsonb_build_object('success',true,'used_today',v_used,'daily_limit',v_access.daily_limit,'remaining',v_access.daily_limit-v_used);
END $$;

REVOKE ALL ON FUNCTION public.consume_aqura_voice_usage(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.consume_aqura_voice_usage(uuid) TO service_role;
NOTIFY pgrst, 'reload schema';
COMMIT;
