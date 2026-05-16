--
-- Name: offer_bundles; Type: TABLE; Schema: public;
--

CREATE TABLE public.offer_bundles (
    id integer NOT NULL,
    offer_id integer NOT NULL,
    bundle_name_ar character varying(255) NOT NULL,
    bundle_name_en character varying(255) NOT NULL,
    required_products jsonb NOT NULL,
    discount_value numeric(10,2) NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    discount_type character varying(20) DEFAULT 'amount'::character varying,
    CONSTRAINT offer_bundles_discount_amount_check CHECK ((discount_value > (0)::numeric)),
    CONSTRAINT offer_bundles_discount_type_check CHECK (((discount_type)::text = ANY (ARRAY[('percentage'::character varying)::text, ('amount'::character varying)::text]))),
    CONSTRAINT offer_bundles_discount_value_check CHECK ((discount_value > (0)::numeric))
);


--
-- Name: offer_bundles_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.offer_bundles_id_seq OWNED BY public.offer_bundles.id;


--
-- Name: offer_bundles id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.offer_bundles ALTER COLUMN id SET DEFAULT nextval('public.offer_bundles_id_seq'::regclass);


--
-- Name: offer_bundles offer_bundles_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.offer_bundles
    ADD CONSTRAINT offer_bundles_pkey PRIMARY KEY (id);


--
-- Name: idx_offer_bundles_offer_id; Type: INDEX; Schema: public;
--

CREATE INDEX idx_offer_bundles_offer_id ON public.offer_bundles USING btree (offer_id);


--
-- Name: offer_bundles trigger_update_offer_bundles_updated_at; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER trigger_update_offer_bundles_updated_at BEFORE UPDATE ON public.offer_bundles FOR EACH ROW EXECUTE FUNCTION public.update_offers_updated_at();


--
-- Name: offer_bundles trigger_validate_bundle_offer_type; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER trigger_validate_bundle_offer_type BEFORE INSERT OR UPDATE ON public.offer_bundles FOR EACH ROW EXECUTE FUNCTION public.validate_bundle_offer_type();


--
-- Name: offer_bundles offer_bundles_offer_id_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.offer_bundles
    ADD CONSTRAINT offer_bundles_offer_id_fkey FOREIGN KEY (offer_id) REFERENCES public.offers(id) ON DELETE CASCADE;


--
-- Name: offer_bundles Allow anon insert offer_bundles; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow anon insert offer_bundles" ON public.offer_bundles FOR INSERT TO anon WITH CHECK (true);


--
-- Name: offer_bundles allow_all_operations; Type: POLICY; Schema: public;
--

CREATE POLICY allow_all_operations ON public.offer_bundles USING (true) WITH CHECK (true);


--
-- Name: offer_bundles allow_delete; Type: POLICY; Schema: public;
--

CREATE POLICY allow_delete ON public.offer_bundles FOR DELETE USING (true);


--
-- Name: offer_bundles allow_insert; Type: POLICY; Schema: public;
--

CREATE POLICY allow_insert ON public.offer_bundles FOR INSERT WITH CHECK (true);


--
-- Name: offer_bundles allow_public_read_bundles; Type: POLICY; Schema: public;
--

CREATE POLICY allow_public_read_bundles ON public.offer_bundles FOR SELECT TO authenticated, anon USING (true);


--
-- Name: offer_bundles allow_select; Type: POLICY; Schema: public;
--

CREATE POLICY allow_select ON public.offer_bundles FOR SELECT USING (true);


--
-- Name: offer_bundles allow_update; Type: POLICY; Schema: public;
--

CREATE POLICY allow_update ON public.offer_bundles FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: offer_bundles anon_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY anon_full_access ON public.offer_bundles USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: offer_bundles authenticated_full_access; Type: POLICY; Schema: public;
--

CREATE POLICY authenticated_full_access ON public.offer_bundles USING ((auth.uid() IS NOT NULL));


--
-- Name: offer_bundles; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.offer_bundles ENABLE ROW LEVEL SECURITY;