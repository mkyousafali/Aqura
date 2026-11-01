BEGIN;
ALTER TABLE public.erp_posting_ledger_links
  DROP CONSTRAINT IF EXISTS erp_posting_ledger_links_account_key_check;
ALTER TABLE public.erp_posting_ledger_links
  ADD CONSTRAINT erp_posting_ledger_links_account_key_check CHECK (account_key IN (
    'branch_cash', 'pos_cash', 'pos_bank', 'pos_short', 'pos_excess',
    'purchase_vouchers', 'charity_sales', 'loyalty_redemption'
  ));
COMMENT ON CONSTRAINT erp_posting_ledger_links_account_key_check ON public.erp_posting_ledger_links
  IS 'POS closing accounts, including non-cash sales reclassified from Branch Cash.';
NOTIFY pgrst, 'reload schema';
COMMIT;
