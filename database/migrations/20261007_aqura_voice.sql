BEGIN;

CREATE TABLE IF NOT EXISTS public.aqura_voice_access (
  user_id uuid PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  is_enabled boolean NOT NULL DEFAULT true,
  daily_limit integer NOT NULL DEFAULT 10 CHECK (daily_limit > 0),
  subscription_expiry date,
  granted_by uuid REFERENCES public.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.aqura_voice_daily_usage (
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  usage_date date NOT NULL,
  usage_count integer NOT NULL DEFAULT 0 CHECK (usage_count >= 0),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, usage_date)
);

ALTER TABLE public.aqura_voice_access ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.aqura_voice_daily_usage ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.aqura_voice_access, public.aqura_voice_daily_usage FROM anon, authenticated;
GRANT ALL ON public.aqura_voice_access, public.aqura_voice_daily_usage TO service_role;

CREATE OR REPLACE FUNCTION public.consume_aqura_voice_usage(p_user_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_master boolean; v_access public.aqura_voice_access%ROWTYPE; v_used integer; v_today date;
BEGIN
  SELECT coalesce(is_master_admin,false) INTO v_master FROM public.users WHERE id=p_user_id AND status='active';
  IF NOT FOUND THEN RETURN jsonb_build_object('success',false,'error','User account is inactive'); END IF;
  IF v_master THEN RETURN jsonb_build_object('success',true,'unlimited',true); END IF;
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
