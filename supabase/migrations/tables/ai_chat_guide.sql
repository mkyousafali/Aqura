--
-- Name: ai_chat_guide; Type: TABLE; Schema: public;
--

CREATE TABLE public.ai_chat_guide (
    id integer NOT NULL,
    guide_text text DEFAULT ''::text NOT NULL,
    updated_by uuid,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: ai_chat_guide_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.ai_chat_guide_id_seq OWNED BY public.ai_chat_guide.id;


--
-- Name: ai_chat_guide id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.ai_chat_guide ALTER COLUMN id SET DEFAULT nextval('public.ai_chat_guide_id_seq'::regclass);


--
-- Name: ai_chat_guide ai_chat_guide_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.ai_chat_guide
    ADD CONSTRAINT ai_chat_guide_pkey PRIMARY KEY (id);


--
-- Name: ai_chat_guide ai_chat_guide_timestamp_update; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER ai_chat_guide_timestamp_update BEFORE UPDATE ON public.ai_chat_guide FOR EACH ROW EXECUTE FUNCTION public.update_ai_chat_guide_timestamp();


--
-- Name: ai_chat_guide ai_chat_guide_updated_by_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.ai_chat_guide
    ADD CONSTRAINT ai_chat_guide_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: ai_chat_guide Allow all access to ai_chat_guide; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow all access to ai_chat_guide" ON public.ai_chat_guide USING (true) WITH CHECK (true);


--
-- Name: ai_chat_guide; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.ai_chat_guide ENABLE ROW LEVEL SECURITY;