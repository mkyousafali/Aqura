--
-- Name: orders; Type: TABLE; Schema: public;
--

CREATE TABLE public.orders (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    order_number character varying(50) NOT NULL,
    customer_id uuid NOT NULL,
    customer_name character varying(255) NOT NULL,
    customer_phone character varying(20) NOT NULL,
    customer_whatsapp character varying(20),
    branch_id bigint NOT NULL,
    selected_location jsonb,
    order_status character varying(50) DEFAULT 'new'::character varying NOT NULL,
    fulfillment_method character varying(20) DEFAULT 'delivery'::character varying NOT NULL,
    subtotal_amount numeric(10,2) DEFAULT 0 NOT NULL,
    delivery_fee numeric(10,2) DEFAULT 0 NOT NULL,
    discount_amount numeric(10,2) DEFAULT 0 NOT NULL,
    tax_amount numeric(10,2) DEFAULT 0 NOT NULL,
    total_amount numeric(10,2) NOT NULL,
    payment_method character varying(20) NOT NULL,
    payment_status character varying(20) DEFAULT 'pending'::character varying NOT NULL,
    payment_reference character varying(100),
    total_items integer DEFAULT 0 NOT NULL,
    total_quantity integer DEFAULT 0 NOT NULL,
    picker_id uuid,
    picker_assigned_at timestamp with time zone,
    delivery_person_id uuid,
    delivery_assigned_at timestamp with time zone,
    accepted_at timestamp with time zone,
    ready_at timestamp with time zone,
    delivered_at timestamp with time zone,
    cancelled_at timestamp with time zone,
    cancelled_by uuid,
    cancellation_reason text,
    customer_notes text,
    admin_notes text,
    estimated_pickup_time timestamp with time zone,
    estimated_delivery_time timestamp with time zone,
    actual_pickup_time timestamp with time zone,
    actual_delivery_time timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    updated_by uuid,
    picked_up_at timestamp with time zone
);

ALTER TABLE ONLY public.orders REPLICA IDENTITY FULL;


--
-- Name: orders orders_order_number_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_order_number_key UNIQUE (order_number);


--
-- Name: orders orders_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_pkey PRIMARY KEY (id);


--
-- Name: idx_orders_branch_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_orders_branch_id ON public.orders USING btree (branch_id);


--
-- Name: idx_orders_branch_status; Type: INDEX; Schema: public;
--

CREATE INDEX idx_orders_branch_status ON public.orders USING btree (branch_id, order_status);


--
-- Name: idx_orders_created_at; Type: INDEX; Schema: public;
--

CREATE INDEX idx_orders_created_at ON public.orders USING btree (created_at DESC);


--
-- Name: idx_orders_customer_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_orders_customer_id ON public.orders USING btree (customer_id);


--
-- Name: idx_orders_customer_status; Type: INDEX; Schema: public;
--

CREATE INDEX idx_orders_customer_status ON public.orders USING btree (customer_id, order_status);


--
-- Name: idx_orders_delivery_person_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_orders_delivery_person_id ON public.orders USING btree (delivery_person_id);


--
-- Name: idx_orders_fulfillment_method; Type: INDEX; Schema: public;
--

CREATE INDEX idx_orders_fulfillment_method ON public.orders USING btree (fulfillment_method);


--
-- Name: idx_orders_order_number; Type: INDEX; Schema: public;
--

CREATE INDEX idx_orders_order_number ON public.orders USING btree (order_number);


--
-- Name: idx_orders_order_status; Type: INDEX; Schema: public;
--

CREATE INDEX idx_orders_order_status ON public.orders USING btree (order_status);


--
-- Name: idx_orders_payment_status; Type: INDEX; Schema: public;
--

CREATE INDEX idx_orders_payment_status ON public.orders USING btree (payment_status);


--
-- Name: idx_orders_picker_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_orders_picker_id ON public.orders USING btree (picker_id);


--
-- Name: idx_orders_status_created; Type: INDEX; Schema: public;
--

CREATE INDEX idx_orders_status_created ON public.orders USING btree (order_status, created_at DESC);


--
-- Name: orders trigger_new_order_notification; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER trigger_new_order_notification AFTER INSERT ON public.orders FOR EACH ROW EXECUTE FUNCTION public.trigger_notify_new_order();


--
-- Name: orders trigger_order_status_change_audit; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER trigger_order_status_change_audit AFTER UPDATE ON public.orders FOR EACH ROW WHEN (((old.order_status)::text IS DISTINCT FROM (new.order_status)::text)) EXECUTE FUNCTION public.trigger_order_status_audit();


--
-- Name: orders update_orders_updated_at; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER update_orders_updated_at BEFORE UPDATE ON public.orders FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- Name: orders orders_branch_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE RESTRICT;


--
-- Name: orders orders_cancelled_by_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_cancelled_by_fkey FOREIGN KEY (cancelled_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: orders orders_created_by_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: orders orders_customer_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON DELETE RESTRICT;


--
-- Name: orders orders_delivery_person_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_delivery_person_id_fkey FOREIGN KEY (delivery_person_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: orders orders_picker_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_picker_id_fkey FOREIGN KEY (picker_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: orders orders_updated_by_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: orders Allow anon insert orders; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon insert orders" ON public.orders FOR INSERT TO anon WITH CHECK (true);


--
-- Name: orders allow_all_operations; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_operations ON public.orders USING (true) WITH CHECK (true);


--
-- Name: orders allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.orders FOR DELETE USING (true);


--
-- Name: orders allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.orders FOR INSERT WITH CHECK (true);


--
-- Name: orders allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.orders FOR SELECT USING (true);


--
-- Name: orders allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.orders FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: orders anon_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY anon_full_access ON public.orders USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: orders authenticated_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY authenticated_full_access ON public.orders USING ((auth.uid() IS NOT NULL));


--
-- Name: orders customers_create_orders; Type: POLICY; Schema: public;
--

CREATE POLICY customers_create_orders ON public.orders FOR INSERT WITH CHECK ((auth.uid() = customer_id));


--
-- Name: orders customers_view_own_orders; Type: POLICY; Schema: public;
--

CREATE POLICY customers_view_own_orders ON public.orders FOR SELECT USING (((auth.uid() = customer_id) OR public.has_order_management_access(auth.uid()) OR public.is_delivery_staff(auth.uid())));


--
-- Name: orders delivery_update_assigned_orders; Type: POLICY; Schema: public;
--

CREATE POLICY delivery_update_assigned_orders ON public.orders FOR UPDATE USING (((delivery_person_id = auth.uid()) OR public.is_delivery_staff(auth.uid()))) WITH CHECK ((((delivery_person_id = auth.uid()) OR public.is_delivery_staff(auth.uid())) AND ((order_status)::text = ANY (ARRAY[('out_for_delivery'::character varying)::text, ('delivered'::character varying)::text]))));


--
-- Name: orders delivery_view_assigned_orders; Type: POLICY; Schema: public;
--

CREATE POLICY delivery_view_assigned_orders ON public.orders FOR SELECT USING (((delivery_person_id = auth.uid()) OR public.is_delivery_staff(auth.uid()) OR public.has_order_management_access(auth.uid())));


--
-- Name: orders management_update_orders; Type: POLICY; Schema: public;
--

CREATE POLICY management_update_orders ON public.orders FOR UPDATE USING (public.has_order_management_access(auth.uid()));


--
-- Name: orders management_view_all_orders; Type: POLICY; Schema: public;
--

CREATE POLICY management_view_all_orders ON public.orders FOR SELECT USING ((public.has_order_management_access(auth.uid()) OR (picker_id = auth.uid()) OR (delivery_person_id = auth.uid())));


--
-- Name: orders; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;


--
-- Name: orders pickers_update_assigned_orders; Type: POLICY; Schema: public;
--

CREATE POLICY pickers_update_assigned_orders ON public.orders FOR UPDATE USING ((picker_id = auth.uid())) WITH CHECK (((picker_id = auth.uid()) AND ((order_status)::text = ANY (ARRAY[('in_picking'::character varying)::text, ('ready'::character varying)::text]))));


--
-- Name: orders pickers_view_assigned_orders; Type: POLICY; Schema: public;
--

CREATE POLICY pickers_view_assigned_orders ON public.orders FOR SELECT USING (((picker_id = auth.uid()) OR public.has_order_management_access(auth.uid())));