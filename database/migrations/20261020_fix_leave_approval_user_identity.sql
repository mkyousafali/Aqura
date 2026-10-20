BEGIN;

-- Leave permissions and approval_approved_by reference public.users.id, which
-- can differ from the Supabase Auth ID represented by auth.uid(). Resolve the
-- existing Aqura session mapping without changing any approval behavior.
DO $migration$
DECLARE
  v_definition text;
  v_old_actor constant text := 'v_actor uuid := auth.uid();';
  v_new_actor constant text := 'v_actor uuid := public.aqura_current_user_id();';
BEGIN
  IF to_regprocedure('public.aqura_current_user_id()') IS NULL THEN
    RAISE EXCEPTION 'The Aqura session identity helper is required';
  END IF;

  SELECT pg_get_functiondef('public.decide_leave_request_days(jsonb,text)'::regprocedure)
    INTO v_definition;

  IF strpos(v_definition, v_old_actor) > 0 THEN
    EXECUTE replace(v_definition, v_old_actor, v_new_actor);
  ELSIF strpos(v_definition, v_new_actor) = 0 THEN
    RAISE EXCEPTION 'Unexpected leave approval actor declaration; no changes applied';
  END IF;
END;
$migration$;

NOTIFY pgrst, 'reload schema';
COMMIT;
