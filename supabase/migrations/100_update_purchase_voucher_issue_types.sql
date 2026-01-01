-- Delete existing issue types
DELETE FROM purchase_voucher_issue_types;

-- Insert new issue types
INSERT INTO purchase_voucher_issue_types (type_name, description) VALUES
  ('gift', 'Issued as a gift'),
  ('sales', 'Issued for sales'),
  ('stock transfer', 'Stock transfer');
