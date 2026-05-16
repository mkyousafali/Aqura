--
-- Name: security_code_scroll_texts; Type: TABLE; Schema: public;
--

CREATE TABLE public.security_code_scroll_texts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    text_content text NOT NULL,
    sort_order integer DEFAULT 0,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    created_by uuid
);


--
-- Name: security_code_scroll_texts security_code_scroll_texts_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.security_code_scroll_texts
    ADD CONSTRAINT security_code_scroll_texts_pkey PRIMARY KEY (id);


--
-- Name: security_code_scroll_texts security_code_scroll_texts_created_by_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.security_code_scroll_texts
    ADD CONSTRAINT security_code_scroll_texts_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: security_code_scroll_texts Allow anon read; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon read" ON public.security_code_scroll_texts FOR SELECT TO anon USING (true);


--
-- Name: security_code_scroll_texts Allow authenticated delete; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow authenticated delete" ON public.security_code_scroll_texts FOR DELETE TO authenticated USING (true);


--
-- Name: security_code_scroll_texts Allow authenticated insert; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow authenticated insert" ON public.security_code_scroll_texts FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: security_code_scroll_texts Allow authenticated read; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow authenticated read" ON public.security_code_scroll_texts FOR SELECT TO authenticated USING (true);


--
-- Name: security_code_scroll_texts Allow authenticated update; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow authenticated update" ON public.security_code_scroll_texts FOR UPDATE TO authenticated USING (true) WITH CHECK (true);


--
-- Name: security_code_scroll_texts; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.security_code_scroll_texts ENABLE ROW LEVEL SECURITY;