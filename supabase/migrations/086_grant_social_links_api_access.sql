-- Grant API access to social_links table

GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON public.social_links TO anon, authenticated, service_role;
