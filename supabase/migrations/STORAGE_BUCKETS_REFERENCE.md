-- Supabase Storage Buckets Reference
-- This file documents all 22 storage buckets configured in the Aqura Supabase instance
-- Created: 2025-12-30
-- Total Buckets: 22

/*
STORAGE BUCKETS INVENTORY
========================

1. EMPLOYEE MANAGEMENT BUCKETS
   - employee-documents: Employee document storage (Created: 2025-09-27)
   - user-avatars: User profile avatars (Created: 2025-09-27)
   - clearance-certificates: Employee clearance documents (Created: 2025-10-16)
   - warning-documents: Employee warning documents (Created: 2025-10-30)

2. DOCUMENT & FILE STORAGE
   - documents: General documents (Created: 2025-09-29)
   - original-bills: Original billing documents (Created: 2025-10-16)
   - vendor-contracts: Vendor contract files (Created: 2025-09-20)

3. PURCHASE & REQUISITION
   - pr-excel-files: Purchase requisition Excel files (Created: 2025-10-18)
   - requisition-images: Requisition related images (Created: 2025-10-26)
   - expense-scheduler-bills: Expense bill receipts (Created: 2025-10-27)

4. TASKS & OPERATIONS
   - task-images: Task related images (Created: 2025-09-29)
   - quick-task-files: Quick task attachments (Created: 2025-10-06)
   - completion-photos: Task completion photos (Created: 2025-09-29)
   - shelf-paper-templates: Shelf label templates (Created: 2025-11-24)

5. NOTIFICATIONS & COMMUNICATIONS
   - notification-images: Notification attachments (Created: 2025-10-05)

6. PROMOTIONS & MARKETING
   - flyer-templates: Promotional flyer templates (Created: 2025-11-25)
   - flyer-product-images: Flyer product images (Created: 2025-11-23)
   - offer-pdfs: Offer PDF documents (Created: 2025-12-29)
   - coupon-product-images: Coupon product photos (Created: 2025-11-26)

7. PRODUCT CATALOG
   - product-images: Product photos (Created: 2025-11-08)
   - category-images: Product category images (Created: 2025-11-08)
   - customer-app-media: Customer app media files (Created: 2025-11-07)

BUCKET PROPERTIES
=================
- All buckets are PUBLIC (accessible without authentication)
- All buckets use Supabase Storage API for file operations
- All files are stored in PostgreSQL's large object storage system
- All buckets support standard file upload/download operations

BUCKET CREATION TIMELINE
========================
2025-09-20: vendor-contracts
2025-09-27: employee-documents, user-avatars
2025-09-29: documents, task-images, completion-photos
2025-10-05: notification-images
2025-10-06: quick-task-files
2025-10-16: original-bills, clearance-certificates
2025-10-18: pr-excel-files
2025-10-26: requisition-images
2025-10-27: expense-scheduler-bills
2025-10-30: warning-documents
2025-11-07: customer-app-media
2025-11-08: category-images, product-images
2025-11-23: flyer-product-images
2025-11-24: shelf-paper-templates
2025-11-25: flyer-templates
2025-11-26: coupon-product-images
2025-12-29: offer-pdfs

STORAGE USAGE BY CATEGORY
==========================

HR & Employee Related:
  - employee-documents
  - user-avatars
  - clearance-certificates
  - warning-documents

Financial & Procurement:
  - original-bills
  - vendor-contracts
  - pr-excel-files
  - requisition-images
  - expense-scheduler-bills

Operations & Tasks:
  - task-images
  - quick-task-files
  - completion-photos
  - shelf-paper-templates
  - documents (general)

Customer & Product Facing:
  - product-images
  - category-images
  - customer-app-media
  - coupon-product-images
  - flyer-product-images
  - flyer-templates
  - offer-pdfs

Communications:
  - notification-images

NOTES
=====
1. All buckets are public to allow direct access to stored files
2. File access is controlled at the application level through RLS policies
3. Storage bucket names follow kebab-case naming convention
4. Bucket IDs match their names exactly
5. Total size limit depends on Supabase storage plan
6. Consider implementing backup strategy for critical buckets
7. Monitor storage usage for optimization opportunities
*/
