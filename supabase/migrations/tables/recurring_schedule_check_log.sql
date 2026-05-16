--
-- Name: recurring_schedule_check_log; Type: TABLE; Schema: public;
--

CREATE TABLE public.recurring_schedule_check_log (
    id integer NOT NULL,
    check_date date DEFAULT CURRENT_DATE NOT NULL,
    schedules_checked integer DEFAULT 0,
    notifications_sent integer DEFAULT 0,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: recurring_schedule_check_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.recurring_schedule_check_log_id_seq OWNED BY public.recurring_schedule_check_log.id;


--
-- Name: recurring_schedule_check_log id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.recurring_schedule_check_log ALTER COLUMN id SET DEFAULT nextval('public.recurring_schedule_check_log_id_seq'::regclass);


--
-- Name: recurring_schedule_check_log recurring_schedule_check_log_check_date_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.recurring_schedule_check_log
    ADD CONSTRAINT recurring_schedule_check_log_check_date_key UNIQUE (check_date);


--
-- Name: recurring_schedule_check_log recurring_schedule_check_log_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.recurring_schedule_check_log
    ADD CONSTRAINT recurring_schedule_check_log_pkey PRIMARY KEY (id);


--
-- Name: recurring_schedule_check_log Allow anon insert recurring_schedule_check_log; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon insert recurring_schedule_check_log" ON public.recurring_schedule_check_log FOR INSERT TO anon WITH CHECK (true);


--
-- Name: recurring_schedule_check_log Only global users can view check logs; Type: POLICY; Schema: public;
--

CREATE POLICY "Only global users can view check logs" ON public.recurring_schedule_check_log FOR SELECT USING ((EXISTS ( SELECT 1
   FROM public.users
  WHERE ((users.id = auth.uid()) AND (users.user_type = 'global'::public.user_type_enum)))));


--
-- Name: recurring_schedule_check_log allow_all_operations; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_operations ON public.recurring_schedule_check_log USING (true) WITH CHECK (true);


--
-- Name: recurring_schedule_check_log allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.recurring_schedule_check_log FOR DELETE USING (true);


--
-- Name: recurring_schedule_check_log allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.recurring_schedule_check_log FOR INSERT WITH CHECK (true);


--
-- Name: recurring_schedule_check_log allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.recurring_schedule_check_log FOR SELECT USING (true);


--
-- Name: recurring_schedule_check_log allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.recurring_schedule_check_log FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: recurring_schedule_check_log anon_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY anon_full_access ON public.recurring_schedule_check_log USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: recurring_schedule_check_log authenticated_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY authenticated_full_access ON public.recurring_schedule_check_log USING ((auth.uid() IS NOT NULL));


--
-- Name: recurring_schedule_check_log; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.recurring_schedule_check_log ENABLE ROW LEVEL SECURITY;