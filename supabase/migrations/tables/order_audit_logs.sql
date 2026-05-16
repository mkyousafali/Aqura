--
-- Name: order_audit_logs; Type: TABLE; Schema: public;
--

CREATE TABLE public.order_audit_logs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    order_id uuid NOT NULL,
    action_type character varying(50) NOT NULL,
    from_status character varying(50),
    to_status character varying(50),
    performed_by uuid,
    performed_by_name character varying(255),
    performed_by_role character varying(50),
    assigned_user_id uuid,
    assigned_user_name character varying(255),
    assignment_type character varying(50),
    field_name character varying(100),
    old_value text,
    new_value text,
    notes text,
    ip_address inet,
    user_agent text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE ONLY public.order_audit_logs REPLICA IDENTITY FULL;


--
-- Name: order_audit_logs order_audit_logs_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.order_audit_logs
    ADD CONSTRAINT order_audit_logs_pkey PRIMARY KEY (id);


--
-- Name: idx_order_audit_logs_action_type; Type: INDEX; Schema: public;
--

CREATE INDEX idx_order_audit_logs_action_type ON public.order_audit_logs USING btree (action_type);


--
-- Name: idx_order_audit_logs_assigned_user; Type: INDEX; Schema: public;
--

CREATE INDEX idx_order_audit_logs_assigned_user ON public.order_audit_logs USING btree (assigned_user_id);


--
-- Name: idx_order_audit_logs_created_at; Type: INDEX; Schema: public;
--

CREATE INDEX idx_order_audit_logs_created_at ON public.order_audit_logs USING btree (created_at DESC);


--
-- Name: idx_order_audit_logs_order_action; Type: INDEX; Schema: public;
--

CREATE INDEX idx_order_audit_logs_order_action ON public.order_audit_logs USING btree (order_id, action_type);


--
-- Name: idx_order_audit_logs_order_created; Type: INDEX; Schema: public;
--

CREATE INDEX idx_order_audit_logs_order_created ON public.order_audit_logs USING btree (order_id, created_at DESC);


--
-- Name: idx_order_audit_logs_order_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_order_audit_logs_order_id ON public.order_audit_logs USING btree (order_id);


--
-- Name: idx_order_audit_logs_performed_by; Type: INDEX; Schema: public;
--

CREATE INDEX idx_order_audit_logs_performed_by ON public.order_audit_logs USING btree (performed_by);


--
-- Name: order_audit_logs trigger_customer_push_on_status_change; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER trigger_customer_push_on_status_change AFTER INSERT ON public.order_audit_logs FOR EACH ROW WHEN (((new.action_type)::text = 'status_change'::text)) EXECUTE FUNCTION public.notify_customer_order_status_change();


--
-- Name: order_audit_logs order_audit_logs_assigned_user_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.order_audit_logs
    ADD CONSTRAINT order_audit_logs_assigned_user_id_fkey FOREIGN KEY (assigned_user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: order_audit_logs order_audit_logs_order_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.order_audit_logs
    ADD CONSTRAINT order_audit_logs_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE CASCADE;


--
-- Name: order_audit_logs order_audit_logs_performed_by_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.order_audit_logs
    ADD CONSTRAINT order_audit_logs_performed_by_fkey FOREIGN KEY (performed_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: order_audit_logs Allow anon insert order_audit_logs; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon insert order_audit_logs" ON public.order_audit_logs FOR INSERT TO anon WITH CHECK (true);


--
-- Name: order_audit_logs allow_all_operations; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_operations ON public.order_audit_logs USING (true) WITH CHECK (true);


--
-- Name: order_audit_logs allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.order_audit_logs FOR DELETE USING (true);


--
-- Name: order_audit_logs allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.order_audit_logs FOR INSERT WITH CHECK (true);


--
-- Name: order_audit_logs allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.order_audit_logs FOR SELECT USING (true);


--
-- Name: order_audit_logs allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.order_audit_logs FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: order_audit_logs anon_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY anon_full_access ON public.order_audit_logs USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: order_audit_logs authenticated_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY authenticated_full_access ON public.order_audit_logs USING ((auth.uid() IS NOT NULL));


--
-- Name: order_audit_logs management_view_all_audit_logs; Type: POLICY; Schema: public;
--

CREATE POLICY management_view_all_audit_logs ON public.order_audit_logs FOR SELECT USING (public.has_order_management_access(auth.uid()));


--
-- Name: order_audit_logs; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.order_audit_logs ENABLE ROW LEVEL SECURITY;


--
-- Name: order_audit_logs system_insert_audit_logs; Type: POLICY; Schema: public;
--

CREATE POLICY system_insert_audit_logs ON public.order_audit_logs FOR INSERT WITH CHECK (true);


--
-- Name: order_audit_logs users_view_order_audit_logs; Type: POLICY; Schema: public;
--

CREATE POLICY users_view_order_audit_logs ON public.order_audit_logs FOR SELECT USING ((order_id IN ( SELECT orders.id
   FROM public.orders
  WHERE ((orders.customer_id = auth.uid()) OR (orders.picker_id = auth.uid()) OR (orders.delivery_person_id = auth.uid()) OR public.has_order_management_access(auth.uid()) OR public.is_delivery_staff(auth.uid())))));