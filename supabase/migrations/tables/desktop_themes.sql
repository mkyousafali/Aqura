--
-- Name: desktop_themes; Type: TABLE; Schema: public;
--

CREATE TABLE public.desktop_themes (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    description character varying(255) DEFAULT ''::character varying,
    is_default boolean DEFAULT false,
    taskbar_bg character varying(100) DEFAULT 'rgba(0, 102, 178, 0.75)'::character varying,
    taskbar_border character varying(100) DEFAULT 'rgba(255, 255, 255, 0.2)'::character varying,
    taskbar_btn_active_bg character varying(100) DEFAULT 'linear-gradient(135deg, #4F46E5, #6366F1)'::character varying,
    taskbar_btn_active_text character varying(30) DEFAULT '#FFFFFF'::character varying,
    taskbar_btn_inactive_bg character varying(30) DEFAULT 'rgba(255, 255, 255, 0.95)'::character varying,
    taskbar_btn_inactive_text character varying(30) DEFAULT '#0B1220'::character varying,
    taskbar_btn_hover_border character varying(30) DEFAULT '#4F46E5'::character varying,
    taskbar_quick_access_bg character varying(100) DEFAULT 'rgba(255, 255, 255, 0.1)'::character varying,
    sidebar_bg character varying(30) DEFAULT '#374151'::character varying,
    sidebar_text character varying(30) DEFAULT '#e5e7eb'::character varying,
    sidebar_border character varying(30) DEFAULT '#1f2937'::character varying,
    sidebar_favorites_bg character varying(30) DEFAULT '#1d2c5e'::character varying,
    sidebar_favorites_text character varying(30) DEFAULT '#fcd34d'::character varying,
    section_btn_bg character varying(30) DEFAULT '#1DBC83'::character varying,
    section_btn_text character varying(30) DEFAULT '#FFFFFF'::character varying,
    section_btn_hover_bg character varying(30) DEFAULT '#3b82f6'::character varying,
    section_btn_hover_text character varying(30) DEFAULT '#FFFFFF'::character varying,
    subsection_btn_bg character varying(30) DEFAULT '#1DBC83'::character varying,
    subsection_btn_text character varying(30) DEFAULT '#FFFFFF'::character varying,
    subsection_btn_hover_bg character varying(30) DEFAULT '#3b82f6'::character varying,
    subsection_btn_hover_text character varying(30) DEFAULT '#FFFFFF'::character varying,
    submenu_item_bg character varying(30) DEFAULT '#FFFFFF'::character varying,
    submenu_item_text character varying(30) DEFAULT '#f97316'::character varying,
    submenu_item_hover_bg character varying(30) DEFAULT '#3b82f6'::character varying,
    submenu_item_hover_text character varying(30) DEFAULT '#FFFFFF'::character varying,
    logo_bar_bg character varying(100) DEFAULT 'linear-gradient(135deg, #15A34A 0%, #22C55E 100%)'::character varying,
    logo_bar_text character varying(30) DEFAULT '#FFFFFF'::character varying,
    logo_border character varying(30) DEFAULT '#F59E0B'::character varying,
    window_title_active_bg character varying(30) DEFAULT '#0066b2'::character varying,
    window_title_active_text character varying(30) DEFAULT '#FFFFFF'::character varying,
    window_title_inactive_bg character varying(100) DEFAULT 'linear-gradient(135deg, #F9FAFB, #E5E7EB)'::character varying,
    window_title_inactive_text character varying(30) DEFAULT '#374151'::character varying,
    window_border_active character varying(30) DEFAULT '#4F46E5'::character varying,
    desktop_bg character varying(30) DEFAULT '#F9FAFB'::character varying,
    desktop_pattern_opacity character varying(10) DEFAULT '0.4'::character varying,
    interface_switch_bg character varying(100) DEFAULT 'linear-gradient(145deg, #3b82f6, #2563eb)'::character varying,
    interface_switch_hover_bg character varying(100) DEFAULT 'linear-gradient(145deg, #2563eb, #1d4ed8)'::character varying,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    created_by uuid
);


--
-- Name: desktop_themes_id_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE public.desktop_themes_id_seq OWNED BY public.desktop_themes.id;


--
-- Name: desktop_themes id; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY public.desktop_themes ALTER COLUMN id SET DEFAULT nextval('public.desktop_themes_id_seq'::regclass);


--
-- Name: desktop_themes desktop_themes_pkey; Type: CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.desktop_themes
    ADD CONSTRAINT desktop_themes_pkey PRIMARY KEY (id);


--
-- Name: idx_desktop_themes_is_default; Type: INDEX; Schema: public;
--

CREATE INDEX idx_desktop_themes_is_default ON public.desktop_themes USING btree (is_default);


--
-- Name: desktop_themes desktop_themes_timestamp_update; Type: TRIGGER; Schema: public;
--

CREATE TRIGGER desktop_themes_timestamp_update BEFORE UPDATE ON public.desktop_themes FOR EACH ROW EXECUTE FUNCTION public.update_desktop_themes_timestamp();


--
-- Name: desktop_themes desktop_themes_created_by_fkey; Type: FK CONSTRAINT; Schema: public;
--

ALTER TABLE ONLY public.desktop_themes
    ADD CONSTRAINT desktop_themes_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: desktop_themes Allow all access to desktop_themes; Type: POLICY; Schema: public;
--

CREATE POLICY "Allow all access to desktop_themes" ON public.desktop_themes USING (true) WITH CHECK (true);


--
-- Name: desktop_themes; Type: ROW SECURITY; Schema: public;
--

ALTER TABLE public.desktop_themes ENABLE ROW LEVEL SECURITY;