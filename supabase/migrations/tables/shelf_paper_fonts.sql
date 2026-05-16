--
-- Name: shelf_paper_fonts; Type: TABLE; Schema: public;
--

CREATE TABLE public.shelf_paper_fonts (
    name character varying(255) NOT NULL,
    font_url text NOT NULL,
    file_name character varying(255),
    file_size integer,
    created_by uuid,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    id character varying(20) DEFAULT ('F'::text || (nextval('public.shelf_paper_fonts_id_seq'::regclass))::text) NOT NULL,
    original_file_name character varying(500)
);


--
-- Name: shelf_paper_fonts shelf_paper_fonts_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.shelf_paper_fonts
    ADD CONSTRAINT shelf_paper_fonts_pkey PRIMARY KEY (id);


--
-- Name: idx_shelf_paper_fonts_created_by; Type: INDEX; Schema: public;
--

CREATE INDEX idx_shelf_paper_fonts_created_by ON public.shelf_paper_fonts USING btree (created_by);


--
-- Name: idx_shelf_paper_fonts_name; Type: INDEX; Schema: public;
--

CREATE INDEX idx_shelf_paper_fonts_name ON public.shelf_paper_fonts USING btree (name);


--
-- Name: shelf_paper_fonts Allow all access to shelf_paper_fonts; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow all access to shelf_paper_fonts" ON public.shelf_paper_fonts USING (true) WITH CHECK (true);


--
-- Name: shelf_paper_fonts; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.shelf_paper_fonts ENABLE ROW LEVEL SECURITY;