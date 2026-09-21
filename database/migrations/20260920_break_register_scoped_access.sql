-- Break data is served by /api/break-register after server-side session
-- validation and scope checks. The service role remains the only direct reader.
BEGIN;

DROP POLICY IF EXISTS "Allow all access to break_register" ON public.break_register;
DROP POLICY IF EXISTS "Allow all access to break_register_permissions" ON public.break_register_permissions;

REVOKE ALL ON TABLE public.break_register FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.break_register_permissions FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.break_register TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.break_register_permissions TO service_role;

REVOKE EXECUTE ON FUNCTION public.get_all_breaks(date,date,integer,character varying) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.get_break_summary_all_employees(date,date,integer) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.get_break_schedule_status(date,date,integer) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.get_active_break(uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.get_mobile_dashboard_data(uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.start_break(uuid,integer,text) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.start_break(uuid,integer,text,text) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.end_break(uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.end_break(uuid,text) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.get_all_breaks(date,date,integer,character varying) TO service_role;
GRANT EXECUTE ON FUNCTION public.get_break_summary_all_employees(date,date,integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.get_break_schedule_status(date,date,integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.get_active_break(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.get_mobile_dashboard_data(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.start_break(uuid,integer,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.start_break(uuid,integer,text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.end_break(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.end_break(uuid,text) TO service_role;

-- SECURITY DEFINER user and HR RPCs previously trusted a caller-supplied
-- requesting user ID. Only the server may invoke them now.
REVOKE EXECUTE ON FUNCTION public.create_user(character varying,character varying,boolean,boolean,character varying,bigint,uuid,uuid,character varying,uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.update_user(uuid,character varying,boolean,boolean,character varying,bigint,uuid,uuid,character varying,text,uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.update_employee_master_basic(text,text,text,integer,uuid,text,text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.create_user(character varying,character varying,boolean,boolean,character varying,bigint,uuid,uuid,character varying,uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.update_user(uuid,character varying,boolean,boolean,character varying,bigint,uuid,uuid,character varying,text,uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.update_employee_master_basic(text,text,text,integer,uuid,text,text) TO service_role;
REVOKE EXECUTE ON FUNCTION public.verify_otp_and_change_access_code(character varying,character varying,character varying,character varying) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.verify_otp_and_change_access_code(character varying,character varying,character varying,character varying) TO service_role;

CREATE OR REPLACE FUNCTION public.guard_break_authority_fields()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE caller_role text := current_setting('request.jwt.claim.role', true);
BEGIN
  IF caller_role IN ('anon', 'authenticated') THEN
    IF TG_TABLE_NAME = 'users' AND (
      NEW.id IS DISTINCT FROM OLD.id OR
      NEW.username IS DISTINCT FROM OLD.username OR
      NEW.is_master_admin IS DISTINCT FROM OLD.is_master_admin OR
      NEW.is_admin IS DISTINCT FROM OLD.is_admin OR
      NEW.password_hash IS DISTINCT FROM OLD.password_hash OR
      NEW.salt IS DISTINCT FROM OLD.salt OR
      NEW.quick_access_code IS DISTINCT FROM OLD.quick_access_code OR
      NEW.quick_access_salt IS DISTINCT FROM OLD.quick_access_salt OR
      NEW.status IS DISTINCT FROM OLD.status OR
      NEW.branch_id IS DISTINCT FROM OLD.branch_id OR
      NEW.employee_id IS DISTINCT FROM OLD.employee_id
    ) THEN RAISE EXCEPTION 'Protected user fields require server authorization'; END IF;
    IF TG_TABLE_NAME = 'hr_employee_master' AND (
      NEW.id IS DISTINCT FROM OLD.id OR
      NEW.user_id IS DISTINCT FROM OLD.user_id OR
      NEW.current_branch_id IS DISTINCT FROM OLD.current_branch_id
    ) THEN RAISE EXCEPTION 'Protected HR fields require server authorization'; END IF;
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS guard_break_user_authority ON public.users;
CREATE TRIGGER guard_break_user_authority BEFORE UPDATE ON public.users
FOR EACH ROW EXECUTE FUNCTION public.guard_break_authority_fields();
DROP TRIGGER IF EXISTS guard_break_hr_authority ON public.hr_employee_master;
CREATE TRIGGER guard_break_hr_authority BEFORE UPDATE ON public.hr_employee_master
FOR EACH ROW EXECUTE FUNCTION public.guard_break_authority_fields();

CREATE OR REPLACE FUNCTION public.guard_break_authority_rows()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF current_setting('request.jwt.claim.role', true) IN ('anon', 'authenticated') THEN
    IF TG_TABLE_NAME = 'users' OR TG_OP = 'DELETE' OR
       (TG_TABLE_NAME = 'hr_employee_master' AND NEW.user_id IS NOT NULL) THEN
      RAISE EXCEPTION 'Protected account and HR rows require server authorization';
    END IF;
  END IF;
  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS guard_break_user_rows ON public.users;
CREATE TRIGGER guard_break_user_rows BEFORE INSERT OR DELETE ON public.users
FOR EACH ROW EXECUTE FUNCTION public.guard_break_authority_rows();
DROP TRIGGER IF EXISTS guard_break_hr_rows ON public.hr_employee_master;
CREATE TRIGGER guard_break_hr_rows BEFORE INSERT OR DELETE ON public.hr_employee_master
FOR EACH ROW EXECUTE FUNCTION public.guard_break_authority_rows();

-- Interface grants are also consulted when issuing a signed session.
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE public.interface_permissions FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.interface_permissions TO service_role;

COMMIT;
