-- Add view tracking columns to view_offer table
ALTER TABLE view_offer
ADD COLUMN view_button_count INTEGER DEFAULT 0,
ADD COLUMN page_visit_count INTEGER DEFAULT 0;
