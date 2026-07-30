-- BUCKET: app-icons
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types) VALUES ('app-icons', 'app-icons', true, 5242880, '{image/png,image/jpeg,image/jpg,image/svg+xml,image/webp,image/gif}') ON CONFLICT (id) DO NOTHING;

-- BUCKET: app-templates
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types) VALUES ('app-templates', 'app-templates', true, 15728640, '{image/png,image/jpeg,image/jpg,image/webp}') ON CONFLICT (id) DO NOTHING;

-- BUCKET: asset-invoices
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types) VALUES ('asset-invoices', 'asset-invoices', true, 52428800, NULL) ON CONFLICT (id) DO NOTHING;

-- BUCKET: category-images
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types) VALUES ('category-images', 'category-images', true, 5242880, '{image/jpeg,image/jpg,image/png,image/webp,image/gif}') ON CONFLICT (id) DO NOTHING;

-- BUCKET: clearance-certificates
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types) VALUES ('clearance-certificates', 'clearance-certificates', true, 10485760, '{image/png,image/jpeg,application/pdf}') ON CONFLICT (id) DO NOTHING;

-- BUCKET: completion-photos
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types) VALUES ('completion-photos', 'completion-photos', true, 52428800, '{image/jpeg,image/png,image/webp,image/gif}') ON CONFLICT (id) DO NOTHING;

-- BUCKET: coupon-product-images
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types) VALUES ('coupon-product-images', 'coupon-product-images', true, NULL, NULL) ON CONFLICT (id) DO NOTHING;

-- BUCKET: customer-app-media
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types) VALUES ('customer-app-media', 'customer-app-media', true, 52428800, NULL) ON CONFLICT (id) DO NOTHING;

-- BUCKET: custom-fonts
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types) VALUES ('custom-fonts', 'custom-fonts', true, 10485760, '{font/ttf,font/otf,font/woff,font/woff2,application/x-font-ttf,application/x-font-otf,application/font-woff,application/font-woff2,application/octet-stream}') ON CONFLICT (id) DO NOTHING;

-- BUCKET: documents
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types) VALUES ('documents', 'documents', true, 52428800, NULL) ON CONFLICT (id) DO NOTHING;

-- BUCKET: email-attachments
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types) VALUES ('email-attachments', 'email-attachments', false, 26214400, '{application/pdf,application/msword,application/vnd.openxmlformats-officedocument.wordprocessingml.document,application/vnd.ms-excel,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet,image/jpeg,image/png,image/gif,image/webp,text/plain,text/csv,application/zip}') ON CONFLICT (id) DO NOTHING;

-- BUCKET: employee-documents
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types) VALUES ('employee-documents', 'employee-documents', true, 10485760, '{image/jpeg,image/jpg,image/png,image/webp,application/pdf,application/msword,application/vnd.openxmlformats-officedocument.wordprocessingml.document}') ON CONFLICT (id) DO NOTHING;

-- BUCKET: expense-scheduler-bills
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types) VALUES ('expense-scheduler-bills', 'expense-scheduler-bills', true, 52428800, '{image/jpeg,image/jpg,image/png,image/gif,image/webp,application/pdf}') ON CONFLICT (id) DO NOTHING;

-- BUCKET: flyer-product-images
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types) VALUES ('flyer-product-images', 'flyer-product-images', true, 20971520, '{image/png,image/jpeg,image/jpg,image/webp}') ON CONFLICT (id) DO NOTHING;

-- BUCKET: flyer-templates
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types) VALUES ('flyer-templates', 'flyer-templates', true, 10485760, '{image/jpeg,image/jpg,image/png,image/webp}') ON CONFLICT (id) DO NOTHING;

-- BUCKET: frontend-builds
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types) VALUES ('frontend-builds', 'frontend-builds', true, 104857600, '{application/zip,application/x-zip-compressed,application/octet-stream}') ON CONFLICT (id) DO NOTHING;

-- BUCKET: helper-apps
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types) VALUES ('helper-apps', 'helper-apps', false, 2097152000, NULL) ON CONFLICT (id) DO NOTHING;

-- BUCKET: notification-images
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types) VALUES ('notification-images', 'notification-images', true, 52428800, '{image/jpeg,image/png,image/gif,image/webp,image/svg+xml,application/pdf,application/msword,application/vnd.openxmlformats-officedocument.wordprocessingml.document,application/vnd.ms-excel,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet,text/csv,text/plain,application/sql,text/sql}') ON CONFLICT (id) DO NOTHING;

-- BUCKET: offer-pdfs
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types) VALUES ('offer-pdfs', 'offer-pdfs', true, NULL, NULL) ON CONFLICT (id) DO NOTHING;

-- BUCKET: original-bills
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types) VALUES ('original-bills', 'original-bills', true, 52428800, '{application/pdf,image/jpeg,image/jpg,image/png,image/gif,image/bmp,image/webp}') ON CONFLICT (id) DO NOTHING;

-- BUCKET: pos-before
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types) VALUES ('pos-before', 'pos-before', true, NULL, NULL) ON CONFLICT (id) DO NOTHING;

-- BUCKET: pr-excel-files
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types) VALUES ('pr-excel-files', 'pr-excel-files', true, 52428800, '{application/vnd.ms-excel,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet,application/excel,application/x-excel,application/x-msexcel}') ON CONFLICT (id) DO NOTHING;

-- BUCKET: product-images
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types) VALUES ('product-images', 'product-images', true, 5242880, '{image/jpeg,image/jpg,image/png,image/webp,image/gif}') ON CONFLICT (id) DO NOTHING;

-- BUCKET: product-request-photos
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types) VALUES ('product-request-photos', 'product-request-photos', true, 20971520, '{image/jpeg,image/jpg,image/png,image/webp}') ON CONFLICT (id) DO NOTHING;

-- BUCKET: purchase-voucher-receipts
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types) VALUES ('purchase-voucher-receipts', 'purchase-voucher-receipts', true, 5242880, '{image/png,image/jpeg}') ON CONFLICT (id) DO NOTHING;

-- BUCKET: quick-task-files
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types) VALUES ('quick-task-files', 'quick-task-files', true, 52428800, '{image/jpeg,image/png,image/gif,image/webp,application/pdf,application/vnd.ms-excel,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet,application/msword,application/vnd.openxmlformats-officedocument.wordprocessingml.document,text/plain,text/csv}') ON CONFLICT (id) DO NOTHING;

-- BUCKET: requisition-images
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types) VALUES ('requisition-images', 'requisition-images', true, 5242880, '{image/png,image/jpeg,image/jpg,application/pdf}') ON CONFLICT (id) DO NOTHING;

-- BUCKET: shelf-paper-templates
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types) VALUES ('shelf-paper-templates', 'shelf-paper-templates', true, 10485760, '{image/jpeg,image/jpg,image/png,image/webp}') ON CONFLICT (id) DO NOTHING;

-- BUCKET: sidebar-animations
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types) VALUES ('sidebar-animations', 'sidebar-animations', true, 5242880, '{application/octet-stream,application/json}') ON CONFLICT (id) DO NOTHING;

-- BUCKET: stock-documents
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types) VALUES ('stock-documents', 'stock-documents', true, 52428800, NULL) ON CONFLICT (id) DO NOTHING;

-- BUCKET: system-backups
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types) VALUES ('system-backups', 'system-backups', true, NULL, NULL) ON CONFLICT (id) DO NOTHING;

-- BUCKET: task-images
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types) VALUES ('task-images', 'task-images', true, 52428800, '{image/jpeg,image/png,image/gif,image/webp,image/svg+xml,application/pdf,application/msword,application/vnd.openxmlformats-officedocument.wordprocessingml.document,application/vnd.ms-excel,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet,text/csv,text/plain,application/sql,text/sql}') ON CONFLICT (id) DO NOTHING;

-- BUCKET: user-avatars
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types) VALUES ('user-avatars', 'user-avatars', true, NULL, NULL) ON CONFLICT (id) DO NOTHING;

-- BUCKET: vendor-contracts
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types) VALUES ('vendor-contracts', 'vendor-contracts', true, 52428800, '{application/pdf}') ON CONFLICT (id) DO NOTHING;

-- BUCKET: warning-documents
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types) VALUES ('warning-documents', 'warning-documents', true, 5242880, '{image/png,image/jpeg,image/jpg,image/webp}') ON CONFLICT (id) DO NOTHING;

-- BUCKET: whatsapp-media
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types) VALUES ('whatsapp-media', 'whatsapp-media', true, 52428800, '{image/jpeg,image/png,image/webp,image/gif,image/avif,video/mp4,video/3gpp,audio/ogg,audio/mpeg,audio/aac,application/pdf,application/octet-stream}') ON CONFLICT (id) DO NOTHING;

