--
-- Name: offer_cart_tiers; Type: TABLE; Schema: public;
--

CREATE TABLE public.offer_cart_tiers (
    id integer NOT NULL,
    offer_id integer NOT NULL,
    tier_number integer NOT NULL,
    min_amount numeric(10,2) NOT NULL,
    max_amount numeric(10,2),
    discount_type character varying(20) NOT NULL,
    discount_value numeric(10,2) NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT offer_cart_tiers_check CHECK (((max_amount IS NULL) OR (max_amount > min_amount))),
    CONSTRAINT offer_cart_tiers_discount_type_check CHECK (((discount_type)::text = ANY (ARRAY[('percentage'::character varying)::text, ('fixed'::character varying)::text]))),
    CONSTRAINT offer_cart_tiers_discount_value_check CHECK ((discount_value >= (0)::numeric)),
    CONSTRAINT offer_cart_tiers_min_amount_check CHECK ((min_amount >= (0)::numeric)),
    CONSTRAINT offer_cart_tiers_tier_number_check CHECK (((tier_number >= 1) AND (tier_number <= 6)))
);


--
-- Name: offer_cart_tiers_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.offer_cart_tiers_id_seq OWNED BY public.offer_cart_tiers.id;


--
-- Name: offer_cart_tiers id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.offer_cart_tiers ALTER COLUMN id SET DEFAULT nextval('public.offer_cart_tiers_id_seq'::regclass);


--
-- Name: offer_cart_tiers offer_cart_tiers_offer_id_min_amount_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.offer_cart_tiers
    ADD CONSTRAINT offer_cart_tiers_offer_id_min_amount_key UNIQUE (offer_id, min_amount);


--
-- Name: offer_cart_tiers offer_cart_tiers_offer_id_tier_number_key; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.offer_cart_tiers
    ADD CONSTRAINT offer_cart_tiers_offer_id_tier_number_key UNIQUE (offer_id, tier_number);


--
-- Name: offer_cart_tiers offer_cart_tiers_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.offer_cart_tiers
    ADD CONSTRAINT offer_cart_tiers_pkey PRIMARY KEY (id);


--
-- Name: idx_offer_cart_tiers_amount_range; Type: INDEX; Schema: public;
--

CREATE INDEX idx_offer_cart_tiers_amount_range ON public.offer_cart_tiers USING btree (min_amount, max_amount);


--
-- Name: idx_offer_cart_tiers_offer_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_offer_cart_tiers_offer_id ON public.offer_cart_tiers USING btree (offer_id);


--
-- Name: offer_cart_tiers update_offer_cart_tiers_updated_at; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER update_offer_cart_tiers_updated_at BEFORE UPDATE ON public.offer_cart_tiers FOR EACH ROW EXECUTE FUNCTION public.update_offer_cart_tiers_updated_at();


--
-- Name: offer_cart_tiers offer_cart_tiers_offer_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.offer_cart_tiers
    ADD CONSTRAINT offer_cart_tiers_offer_id_fkey FOREIGN KEY (offer_id) REFERENCES public.offers(id) ON DELETE CASCADE;


--
-- Name: offer_cart_tiers Allow anon insert offer_cart_tiers; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon insert offer_cart_tiers" ON public.offer_cart_tiers FOR INSERT TO anon WITH CHECK (true);


--
-- Name: offer_cart_tiers admin_all_offer_cart_tiers; Type: POLICY; Schema: public;
--

CREATE POLICY admin_all_offer_cart_tiers ON public.offer_cart_tiers USING (true) WITH CHECK (true);


--
-- Name: offer_cart_tiers allow_all_operations; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_operations ON public.offer_cart_tiers USING (true) WITH CHECK (true);


--
-- Name: offer_cart_tiers allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.offer_cart_tiers FOR DELETE USING (true);


--
-- Name: offer_cart_tiers allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.offer_cart_tiers FOR INSERT WITH CHECK (true);


--
-- Name: offer_cart_tiers allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.offer_cart_tiers FOR SELECT USING (true);


--
-- Name: offer_cart_tiers allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.offer_cart_tiers FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: offer_cart_tiers anon_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY anon_full_access ON public.offer_cart_tiers USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: offer_cart_tiers authenticated_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY authenticated_full_access ON public.offer_cart_tiers USING ((auth.uid() IS NOT NULL));


--
-- Name: offer_cart_tiers; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.offer_cart_tiers ENABLE ROW LEVEL SECURITY;