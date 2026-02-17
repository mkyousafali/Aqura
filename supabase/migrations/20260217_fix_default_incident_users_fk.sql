-- Fix foreign keys: change from auth.users to public.users
ALTER TABLE public.default_incident_users DROP CONSTRAINT IF EXISTS default_incident_users_user_id_fkey;
ALTER TABLE public.default_incident_users ADD CONSTRAINT default_incident_users_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

ALTER TABLE public.default_incident_users DROP CONSTRAINT IF EXISTS default_incident_users_created_by_fkey;
ALTER TABLE public.default_incident_users ADD CONSTRAINT default_incident_users_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);
