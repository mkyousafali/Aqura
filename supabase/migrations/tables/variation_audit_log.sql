--
-- Name: variation_audit_log; Type: TABLE; Schema: public;
--

CREATE TABLE public.variation_audit_log (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    action_type text NOT NULL,
    variation_group_id uuid,
    affected_barcodes text[],
    parent_barcode text,
    group_name_en text,
    group_name_ar text,
    user_id uuid,
    "timestamp" timestamp with time zone DEFAULT now() NOT NULL,
    details jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT variation_audit_log_action_type_check CHECK ((action_type = ANY (ARRAY['create_group'::text, 'edit_group'::text, 'delete_group'::text, 'add_variation'::text, 'remove_variation'::text, 'reorder_variations'::text, 'change_parent'::text, 'update_image_override'::text])))
);


--
-- Name: variation_audit_log variation_audit_log_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.variation_audit_log
    ADD CONSTRAINT variation_audit_log_pkey PRIMARY KEY (id);


--
-- Name: idx_variation_audit_log_action_type; Type: INDEX; Schema: public;
--

CREATE INDEX idx_variation_audit_log_action_type ON public.variation_audit_log USING btree (action_type);


--
-- Name: idx_variation_audit_log_parent_barcode; Type: INDEX; Schema: public;
--

CREATE INDEX idx_variation_audit_log_parent_barcode ON public.variation_audit_log USING btree (parent_barcode) WHERE (parent_barcode IS NOT NULL);


--
-- Name: idx_variation_audit_log_timestamp; Type: INDEX; Schema: public;
--

CREATE INDEX idx_variation_audit_log_timestamp ON public.variation_audit_log USING btree ("timestamp" DESC);


--
-- Name: idx_variation_audit_log_user_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_variation_audit_log_user_id ON public.variation_audit_log USING btree (user_id);


--
-- Name: idx_variation_audit_log_variation_group_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_variation_audit_log_variation_group_id ON public.variation_audit_log USING btree (variation_group_id) WHERE (variation_group_id IS NOT NULL);


--
-- Name: variation_audit_log variation_audit_log_user_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.variation_audit_log
    ADD CONSTRAINT variation_audit_log_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: variation_audit_log Allow anon insert variation_audit_log; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon insert variation_audit_log" ON public.variation_audit_log FOR INSERT TO anon WITH CHECK (true);


--
-- Name: variation_audit_log System can insert variation audit logs; Type: POLICY; Schema: public;
--

CREATE POLICY "System can insert variation audit logs" ON public.variation_audit_log FOR INSERT WITH CHECK (true);


--
-- Name: variation_audit_log Users can view variation audit logs; Type: POLICY; Schema: public;
--

CREATE POLICY "Users can view variation audit logs" ON public.variation_audit_log FOR SELECT USING (true);


--
-- Name: variation_audit_log allow_all_operations; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_operations ON public.variation_audit_log USING (true) WITH CHECK (true);


--
-- Name: variation_audit_log allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.variation_audit_log FOR DELETE USING (true);


--
-- Name: variation_audit_log allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.variation_audit_log FOR INSERT WITH CHECK (true);


--
-- Name: variation_audit_log allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.variation_audit_log FOR SELECT USING (true);


--
-- Name: variation_audit_log allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.variation_audit_log FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: variation_audit_log anon_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY anon_full_access ON public.variation_audit_log USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: variation_audit_log authenticated_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY authenticated_full_access ON public.variation_audit_log USING ((auth.uid() IS NOT NULL));


--
-- Name: variation_audit_log; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.variation_audit_log ENABLE ROW LEVEL SECURITY;