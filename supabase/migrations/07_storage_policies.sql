-- STORAGE POLICY: Allow anon delete from custom-fonts ON objects
CREATE POLICY "Allow anon delete from custom-fonts" ON storage.objects FOR DELETE USING ((bucket_id = 'custom-fonts'::text));

-- STORAGE POLICY: Allow anon insert offer-pdfs ON objects
CREATE POLICY "Allow anon insert offer-pdfs" ON storage.objects FOR INSERT WITH CHECK (((bucket_id = 'offer-pdfs'::text) AND true));

-- STORAGE POLICY: Allow anon upload to custom-fonts ON objects
CREATE POLICY "Allow anon upload to custom-fonts" ON storage.objects FOR INSERT WITH CHECK ((bucket_id = 'custom-fonts'::text));

-- STORAGE POLICY: Allow authenticated delete from custom-fonts ON objects
CREATE POLICY "Allow authenticated delete from custom-fonts" ON storage.objects FOR DELETE USING ((bucket_id = 'custom-fonts'::text));

-- STORAGE POLICY: Allow authenticated upload to custom-fonts ON objects
CREATE POLICY "Allow authenticated upload to custom-fonts" ON storage.objects FOR INSERT WITH CHECK ((bucket_id = 'custom-fonts'::text));

-- STORAGE POLICY: Allow authenticated users to delete from pos-before ON objects
CREATE POLICY "Allow authenticated users to delete from pos-before" ON storage.objects FOR DELETE TO authenticated USING ((bucket_id = 'pos-before'::text));

-- STORAGE POLICY: Allow authenticated users to read files ON objects
CREATE POLICY "Allow authenticated users to read files" ON storage.objects FOR SELECT USING (((bucket_id = 'offer-pdfs'::text) AND true));

-- STORAGE POLICY: Allow authenticated users to read pos-before ON objects
CREATE POLICY "Allow authenticated users to read pos-before" ON storage.objects FOR SELECT TO authenticated USING ((bucket_id = 'pos-before'::text));

-- STORAGE POLICY: Allow authenticated users to update files ON objects
CREATE POLICY "Allow authenticated users to update files" ON storage.objects FOR UPDATE USING (((bucket_id = 'offer-pdfs'::text) AND true)) WITH CHECK (((bucket_id = 'offer-pdfs'::text) AND true));

-- STORAGE POLICY: Allow authenticated users to upload files ON objects
CREATE POLICY "Allow authenticated users to upload files" ON storage.objects FOR INSERT WITH CHECK (((bucket_id = 'offer-pdfs'::text) AND true));

-- STORAGE POLICY: Allow authenticated users to upload to pos-before ON objects
CREATE POLICY "Allow authenticated users to upload to pos-before" ON storage.objects FOR INSERT TO authenticated WITH CHECK ((bucket_id = 'pos-before'::text));

-- STORAGE POLICY: Allow delete for asset invoices ON objects
CREATE POLICY "Allow delete for asset invoices" ON storage.objects FOR DELETE USING ((bucket_id = 'asset-invoices'::text));

-- STORAGE POLICY: Allow delete for stock documents ON objects
CREATE POLICY "Allow delete for stock documents" ON storage.objects FOR DELETE USING ((bucket_id = 'stock-documents'::text));

-- STORAGE POLICY: Allow delete on product-request-photos ON objects
CREATE POLICY "Allow delete on product-request-photos" ON storage.objects FOR DELETE USING ((bucket_id = 'product-request-photos'::text));

-- STORAGE POLICY: Allow public read access on product-request-photos ON objects
CREATE POLICY "Allow public read access on product-request-photos" ON storage.objects FOR SELECT USING ((bucket_id = 'product-request-photos'::text));

-- STORAGE POLICY: Allow public read access to custom-fonts ON objects
CREATE POLICY "Allow public read access to custom-fonts" ON storage.objects FOR SELECT USING ((bucket_id = 'custom-fonts'::text));

-- STORAGE POLICY: Allow update for asset invoices ON objects
CREATE POLICY "Allow update for asset invoices" ON storage.objects FOR UPDATE USING ((bucket_id = 'asset-invoices'::text));

-- STORAGE POLICY: Allow update for stock documents ON objects
CREATE POLICY "Allow update for stock documents" ON storage.objects FOR UPDATE USING ((bucket_id = 'stock-documents'::text));

-- STORAGE POLICY: Allow update on product-request-photos ON objects
CREATE POLICY "Allow update on product-request-photos" ON storage.objects FOR UPDATE USING ((bucket_id = 'product-request-photos'::text));

-- STORAGE POLICY: Allow upload for asset invoices ON objects
CREATE POLICY "Allow upload for asset invoices" ON storage.objects FOR INSERT WITH CHECK ((bucket_id = 'asset-invoices'::text));

-- STORAGE POLICY: Allow upload for stock documents ON objects
CREATE POLICY "Allow upload for stock documents" ON storage.objects FOR INSERT WITH CHECK ((bucket_id = 'stock-documents'::text));

-- STORAGE POLICY: Allow upload on product-request-photos ON objects
CREATE POLICY "Allow upload on product-request-photos" ON storage.objects FOR INSERT WITH CHECK ((bucket_id = 'product-request-photos'::text));

-- STORAGE POLICY: Anyone can read frontend builds ON objects
CREATE POLICY "Anyone can read frontend builds" ON storage.objects FOR SELECT USING ((bucket_id = 'frontend-builds'::text));

-- STORAGE POLICY: Auth users manage sidebar-animations ON objects
CREATE POLICY "Auth users manage sidebar-animations" ON storage.objects FOR ALL USING ((bucket_id = 'sidebar-animations'::text)) WITH CHECK ((bucket_id = 'sidebar-animations'::text));

-- STORAGE POLICY: Authenticated delete from app-icons ON objects
CREATE POLICY "Authenticated delete from app-icons" ON storage.objects FOR DELETE TO authenticated USING ((bucket_id = 'app-icons'::text));

-- STORAGE POLICY: Authenticated update app-icons ON objects
CREATE POLICY "Authenticated update app-icons" ON storage.objects FOR UPDATE TO authenticated USING ((bucket_id = 'app-icons'::text));

-- STORAGE POLICY: Authenticated upload to app-icons ON objects
CREATE POLICY "Authenticated upload to app-icons" ON storage.objects FOR INSERT TO authenticated WITH CHECK ((bucket_id = 'app-icons'::text));

-- STORAGE POLICY: Authenticated users can read receipts ON objects
CREATE POLICY "Authenticated users can read receipts" ON storage.objects FOR SELECT TO authenticated USING ((bucket_id = 'purchase-voucher-receipts'::text));

-- STORAGE POLICY: Authenticated users can upload frontend builds ON objects
CREATE POLICY "Authenticated users can upload frontend builds" ON storage.objects FOR INSERT TO authenticated WITH CHECK ((bucket_id = 'frontend-builds'::text));

-- STORAGE POLICY: Authenticated users can upload receipts ON objects
CREATE POLICY "Authenticated users can upload receipts" ON storage.objects FOR INSERT TO authenticated WITH CHECK ((bucket_id = 'purchase-voucher-receipts'::text));

-- STORAGE POLICY: Enable all access to offer-pdfs ON objects
CREATE POLICY "Enable all access to offer-pdfs" ON storage.objects FOR ALL USING ((bucket_id = 'offer-pdfs'::text)) WITH CHECK ((bucket_id = 'offer-pdfs'::text));

-- STORAGE POLICY: Public can view receipts ON objects
CREATE POLICY "Public can view receipts" ON storage.objects FOR SELECT USING ((bucket_id = 'purchase-voucher-receipts'::text));

-- STORAGE POLICY: Public read access for app-icons ON objects
CREATE POLICY "Public read access for app-icons" ON storage.objects FOR SELECT USING ((bucket_id = 'app-icons'::text));

-- STORAGE POLICY: Public read access for asset invoices ON objects
CREATE POLICY "Public read access for asset invoices" ON storage.objects FOR SELECT USING ((bucket_id = 'asset-invoices'::text));

-- STORAGE POLICY: Public read access for stock documents ON objects
CREATE POLICY "Public read access for stock documents" ON storage.objects FOR SELECT USING ((bucket_id = 'stock-documents'::text));

-- STORAGE POLICY: Public read sidebar-animations ON objects
CREATE POLICY "Public read sidebar-animations" ON storage.objects FOR SELECT USING ((bucket_id = 'sidebar-animations'::text));

-- STORAGE POLICY: Public read whatsapp media ON objects
CREATE POLICY "Public read whatsapp media" ON storage.objects FOR SELECT USING ((bucket_id = 'whatsapp-media'::text));

-- STORAGE POLICY: Service role has full access to files ON objects
CREATE POLICY "Service role has full access to files" ON storage.objects FOR ALL USING (((bucket_id = 'offer-pdfs'::text) AND true)) WITH CHECK (((bucket_id = 'offer-pdfs'::text) AND true));

-- STORAGE POLICY: Service role manage frontend builds ON objects
CREATE POLICY "Service role manage frontend builds" ON storage.objects FOR ALL TO service_role USING ((bucket_id = 'frontend-builds'::text)) WITH CHECK ((bucket_id = 'frontend-builds'::text));

-- STORAGE POLICY: Service upload whatsapp media ON objects
CREATE POLICY "Service upload whatsapp media" ON storage.objects FOR INSERT WITH CHECK ((bucket_id = 'whatsapp-media'::text));

-- STORAGE POLICY: allow_all_operations for files ON objects
CREATE POLICY "allow_all_operations for files" ON storage.objects FOR ALL USING (((bucket_id = 'offer-pdfs'::text) AND true)) WITH CHECK (((bucket_id = 'offer-pdfs'::text) AND true));

-- STORAGE POLICY: allow_all_storage ON objects
CREATE POLICY allow_all_storage ON storage.objects FOR ALL USING (true) WITH CHECK (true);

-- STORAGE POLICY: allow_delete ON objects
CREATE POLICY allow_delete ON storage.objects FOR DELETE USING (true);

-- STORAGE POLICY: allow_delete files ON objects
CREATE POLICY "allow_delete files" ON storage.objects FOR DELETE USING (((bucket_id = 'offer-pdfs'::text) AND true));

-- STORAGE POLICY: allow_insert ON objects
CREATE POLICY allow_insert ON storage.objects FOR INSERT WITH CHECK (true);

-- STORAGE POLICY: allow_select ON objects
CREATE POLICY allow_select ON storage.objects FOR SELECT USING (true);

-- STORAGE POLICY: allow_select files ON objects
CREATE POLICY "allow_select files" ON storage.objects FOR SELECT USING (((bucket_id = 'offer-pdfs'::text) AND true));

-- STORAGE POLICY: allow_update ON objects
CREATE POLICY allow_update ON storage.objects FOR UPDATE USING (true) WITH CHECK (true);

-- STORAGE POLICY: allow_update files ON objects
CREATE POLICY "allow_update files" ON storage.objects FOR UPDATE USING (((bucket_id = 'offer-pdfs'::text) AND true)) WITH CHECK (((bucket_id = 'offer-pdfs'::text) AND true));

-- STORAGE POLICY: anon_full_access files ON objects
CREATE POLICY "anon_full_access files" ON storage.objects FOR ALL USING (((bucket_id = 'offer-pdfs'::text) AND ((jwt() ->> 'role'::text) = 'anon'::text)));

-- STORAGE POLICY: app_templates_delete ON objects
CREATE POLICY app_templates_delete ON storage.objects FOR DELETE TO authenticated, anon USING ((bucket_id = 'app-templates'::text));

-- STORAGE POLICY: app_templates_insert ON objects
CREATE POLICY app_templates_insert ON storage.objects FOR INSERT TO authenticated, anon WITH CHECK ((bucket_id = 'app-templates'::text));

-- STORAGE POLICY: app_templates_select ON objects
CREATE POLICY app_templates_select ON storage.objects FOR SELECT TO authenticated, anon USING ((bucket_id = 'app-templates'::text));

-- STORAGE POLICY: app_templates_update ON objects
CREATE POLICY app_templates_update ON storage.objects FOR UPDATE TO authenticated, anon USING ((bucket_id = 'app-templates'::text));

-- STORAGE POLICY: authenticated_full_access files ON objects
CREATE POLICY "authenticated_full_access files" ON storage.objects FOR ALL USING (((bucket_id = 'offer-pdfs'::text) AND (uid() IS NOT NULL)));

-- STORAGE POLICY: helper_apps_storage_delete ON objects
CREATE POLICY helper_apps_storage_delete ON storage.objects FOR DELETE TO authenticated, anon USING ((bucket_id = 'helper-apps'::text));

-- STORAGE POLICY: helper_apps_storage_insert ON objects
CREATE POLICY helper_apps_storage_insert ON storage.objects FOR INSERT TO authenticated, anon WITH CHECK ((bucket_id = 'helper-apps'::text));

-- STORAGE POLICY: helper_apps_storage_select ON objects
CREATE POLICY helper_apps_storage_select ON storage.objects FOR SELECT TO authenticated, anon USING ((bucket_id = 'helper-apps'::text));

-- STORAGE POLICY: helper_apps_storage_update ON objects
CREATE POLICY helper_apps_storage_update ON storage.objects FOR UPDATE TO authenticated, anon USING ((bucket_id = 'helper-apps'::text)) WITH CHECK ((bucket_id = 'helper-apps'::text));

