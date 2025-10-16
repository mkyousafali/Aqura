-- =============================================
-- Simple Receiving Records Table Schema
-- Records basic receiving information only
-- =============================================

CREATE TABLE receiving_records (
    -- Primary identification
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- User who is performing the receiving
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    
    -- Selected branch for this receiving
    branch_id INTEGER NOT NULL REFERENCES branches(id) ON DELETE RESTRICT,
    
    -- Selected vendor for this receiving  
    vendor_id INTEGER NOT NULL REFERENCES vendors(erp_vendor_id) ON DELETE RESTRICT,
    
    -- Date entered from the bill
    bill_date DATE NOT NULL,
    
    -- Bill amount entered by user
    bill_amount DECIMAL(15,2) NOT NULL,
    
    -- Bill number from the physical bill
    bill_number VARCHAR(100),
    
    -- Payment information (can be different from vendor default)
    payment_method VARCHAR(100),
    credit_period INTEGER,
    due_date DATE,
    bank_name VARCHAR(200),
    iban VARCHAR(50),
    
    -- VAT verification information
    vendor_vat_number VARCHAR(50),
    bill_vat_number VARCHAR(50),
    vat_numbers_match BOOLEAN,
    vat_mismatch_reason TEXT,
    
    -- Branch manager/responsible user selection
    branch_manager_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    
    -- Shelf stockers selection (multiple users)
    shelf_stocker_user_ids UUID[] DEFAULT '{}',
    
    -- Accountant selection (single user)
    accountant_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    
    -- Purchasing Manager selection (single user)
    purchasing_manager_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    
    -- Return amounts for different categories
    expired_return_amount DECIMAL(12,2) DEFAULT 0,
    near_expiry_return_amount DECIMAL(12,2) DEFAULT 0,
    over_stock_return_amount DECIMAL(12,2) DEFAULT 0,
    damage_return_amount DECIMAL(12,2) DEFAULT 0,
    total_return_amount DECIMAL(12,2) DEFAULT 0,
    final_bill_amount DECIMAL(12,2) DEFAULT 0,
    
    -- ERP Document information for each return category
    expired_erp_document_type VARCHAR(10),
    expired_erp_document_number VARCHAR(100),
    expired_vendor_document_number VARCHAR(100),
    near_expiry_erp_document_type VARCHAR(10),
    near_expiry_erp_document_number VARCHAR(100),
    near_expiry_vendor_document_number VARCHAR(100),
    over_stock_erp_document_type VARCHAR(10),
    over_stock_erp_document_number VARCHAR(100),
    over_stock_vendor_document_number VARCHAR(100),
    damage_erp_document_type VARCHAR(10),
    damage_erp_document_number VARCHAR(100),
    damage_vendor_document_number VARCHAR(100),
    
    -- Return questions answered
    has_expired_returns BOOLEAN DEFAULT false,
    has_near_expiry_returns BOOLEAN DEFAULT false,
    has_over_stock_returns BOOLEAN DEFAULT false,
    has_damage_returns BOOLEAN DEFAULT false,
    
    -- Automatically track when record was created
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================
-- Indexes for Performance
-- =============================================

CREATE INDEX idx_receiving_records_user_id ON receiving_records(user_id);
CREATE INDEX idx_receiving_records_branch_id ON receiving_records(branch_id);
CREATE INDEX idx_receiving_records_vendor_id ON receiving_records(vendor_id);
CREATE INDEX idx_receiving_records_branch_manager_user_id ON receiving_records(branch_manager_user_id);
CREATE INDEX idx_receiving_records_accountant_user_id ON receiving_records(accountant_user_id);
CREATE INDEX idx_receiving_records_purchasing_manager_user_id ON receiving_records(purchasing_manager_user_id);
CREATE INDEX idx_receiving_records_bill_date ON receiving_records(bill_date);
CREATE INDEX idx_receiving_records_due_date ON receiving_records(due_date);
CREATE INDEX idx_receiving_records_bill_amount ON receiving_records(bill_amount);
CREATE INDEX idx_receiving_records_bill_number ON receiving_records(bill_number);
CREATE INDEX idx_receiving_records_payment_method ON receiving_records(payment_method);
CREATE INDEX idx_receiving_records_credit_period ON receiving_records(credit_period);
CREATE INDEX idx_receiving_records_bank_name ON receiving_records(bank_name);
CREATE INDEX idx_receiving_records_iban ON receiving_records(iban);
CREATE INDEX idx_receiving_records_vendor_vat_number ON receiving_records(vendor_vat_number);
CREATE INDEX idx_receiving_records_bill_vat_number ON receiving_records(bill_vat_number);
CREATE INDEX idx_receiving_records_vat_numbers_match ON receiving_records(vat_numbers_match);
CREATE INDEX idx_receiving_records_expired_erp_document_number ON receiving_records(expired_erp_document_number);
CREATE INDEX idx_receiving_records_expired_vendor_document_number ON receiving_records(expired_vendor_document_number);
CREATE INDEX idx_receiving_records_near_expiry_erp_document_number ON receiving_records(near_expiry_erp_document_number);
CREATE INDEX idx_receiving_records_near_expiry_vendor_document_number ON receiving_records(near_expiry_vendor_document_number);
CREATE INDEX idx_receiving_records_over_stock_erp_document_number ON receiving_records(over_stock_erp_document_number);
CREATE INDEX idx_receiving_records_over_stock_vendor_document_number ON receiving_records(over_stock_vendor_document_number);
CREATE INDEX idx_receiving_records_damage_erp_document_number ON receiving_records(damage_erp_document_number);
CREATE INDEX idx_receiving_records_damage_vendor_document_number ON receiving_records(damage_vendor_document_number);
CREATE INDEX idx_receiving_records_total_return_amount ON receiving_records(total_return_amount);
CREATE INDEX idx_receiving_records_final_bill_amount ON receiving_records(final_bill_amount);
CREATE INDEX idx_receiving_records_created_at ON receiving_records(created_at);

-- Index for shelf stocker user IDs (using GIN for array operations)
CREATE INDEX idx_receiving_records_shelf_stocker_user_ids ON receiving_records USING GIN(shelf_stocker_user_ids);

-- =============================================
-- Row Level Security (RLS)
-- =============================================

-- Enable RLS
ALTER TABLE receiving_records ENABLE ROW LEVEL SECURITY;

-- Users can only see receiving records from their own branch
CREATE POLICY "Users can view receiving records from their branch" ON receiving_records
    FOR SELECT USING (
        branch_id IN (
            SELECT branch_id 
            FROM users 
            WHERE id = auth.uid()
        )
    );

-- Users can only insert receiving records for their own branch
CREATE POLICY "Users can insert receiving records for their branch" ON receiving_records
    FOR INSERT WITH CHECK (
        branch_id IN (
            SELECT branch_id 
            FROM users 
            WHERE id = auth.uid()
        ) AND user_id = auth.uid()
    );

-- Users can update their own receiving records from their branch
-- Branch managers can also update receiving records they are assigned to
CREATE POLICY "Users can update their own receiving records" ON receiving_records
    FOR UPDATE USING (
        (user_id = auth.uid() OR branch_manager_user_id = auth.uid()) AND 
        branch_id IN (
            SELECT branch_id 
            FROM users 
            WHERE id = auth.uid()
        )
    );

-- =============================================
-- Check Constraints for Return Amounts
-- =============================================

-- Ensure return amounts are not negative
ALTER TABLE receiving_records 
ADD CONSTRAINT check_expired_return_amount CHECK (expired_return_amount >= 0),
ADD CONSTRAINT check_near_expiry_return_amount CHECK (near_expiry_return_amount >= 0),
ADD CONSTRAINT check_over_stock_return_amount CHECK (over_stock_return_amount >= 0),
ADD CONSTRAINT check_damage_return_amount CHECK (damage_return_amount >= 0),
ADD CONSTRAINT check_total_return_amount CHECK (total_return_amount >= 0),
ADD CONSTRAINT check_final_bill_amount CHECK (final_bill_amount >= 0);

-- Ensure return amounts don't exceed bill amount
ALTER TABLE receiving_records 
ADD CONSTRAINT check_return_not_exceed_bill CHECK (total_return_amount <= bill_amount);

-- Ensure due date is after or equal to bill date when both are present
ALTER TABLE receiving_records 
ADD CONSTRAINT check_due_date_after_bill_date CHECK (
    due_date IS NULL OR bill_date IS NULL OR due_date >= bill_date
);

-- Ensure VAT mismatch reason is provided when VAT numbers don't match
ALTER TABLE receiving_records 
ADD CONSTRAINT check_vat_mismatch_reason CHECK (
    vat_numbers_match IS NULL OR 
    vat_numbers_match = true OR 
    (vat_numbers_match = false AND vat_mismatch_reason IS NOT NULL AND length(trim(vat_mismatch_reason)) > 0)
);

-- Ensure credit period is positive when present
ALTER TABLE receiving_records 
ADD CONSTRAINT check_credit_period_positive CHECK (credit_period IS NULL OR credit_period >= 0);

-- =============================================
-- Trigger to Auto-Calculate Return Totals
-- =============================================

-- Function to automatically calculate total_return_amount and final_bill_amount
CREATE OR REPLACE FUNCTION calculate_return_totals()
RETURNS TRIGGER AS $$
BEGIN
  -- Calculate total return amount
  NEW.total_return_amount = COALESCE(NEW.expired_return_amount, 0) + 
                           COALESCE(NEW.near_expiry_return_amount, 0) + 
                           COALESCE(NEW.over_stock_return_amount, 0) + 
                           COALESCE(NEW.damage_return_amount, 0);
  
  -- Calculate final bill amount
  NEW.final_bill_amount = COALESCE(NEW.bill_amount, 0) - NEW.total_return_amount;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
CREATE TRIGGER trigger_calculate_return_totals
  BEFORE INSERT OR UPDATE ON receiving_records
  FOR EACH ROW
  EXECUTE FUNCTION calculate_return_totals();

-- =============================================
-- Comments for Documentation
-- =============================================

COMMENT ON TABLE receiving_records IS 'Receiving records with bill information and return processing';
COMMENT ON COLUMN receiving_records.user_id IS 'User who performed the receiving';
COMMENT ON COLUMN receiving_records.branch_id IS 'Branch where receiving was performed';
COMMENT ON COLUMN receiving_records.vendor_id IS 'Vendor from whom goods were received';
COMMENT ON COLUMN receiving_records.bill_date IS 'Date entered from the physical bill';
COMMENT ON COLUMN receiving_records.bill_amount IS 'Total amount from the bill';
COMMENT ON COLUMN receiving_records.bill_number IS 'Bill number from the physical bill';
COMMENT ON COLUMN receiving_records.payment_method IS 'Payment method for this receiving (can differ from vendor default)';
COMMENT ON COLUMN receiving_records.credit_period IS 'Credit period in days for this receiving (can differ from vendor default)';
COMMENT ON COLUMN receiving_records.due_date IS 'Calculated due date (bill date + credit period) for credit payment methods';
COMMENT ON COLUMN receiving_records.bank_name IS 'Bank name for this receiving (can differ from vendor default)';
COMMENT ON COLUMN receiving_records.iban IS 'IBAN for this receiving (can differ from vendor default)';
COMMENT ON COLUMN receiving_records.vendor_vat_number IS 'VAT number from vendor record at time of receiving';
COMMENT ON COLUMN receiving_records.bill_vat_number IS 'VAT number entered from the physical bill';
COMMENT ON COLUMN receiving_records.vat_numbers_match IS 'Whether vendor and bill VAT numbers match';
COMMENT ON COLUMN receiving_records.vat_mismatch_reason IS 'Reason provided when VAT numbers do not match';
COMMENT ON COLUMN receiving_records.branch_manager_user_id IS 'Selected branch manager or responsible user for this receiving';
COMMENT ON COLUMN receiving_records.shelf_stocker_user_ids IS 'Array of user IDs selected as shelf stockers for this receiving';
COMMENT ON COLUMN receiving_records.accountant_user_id IS 'Selected accountant or responsible user for accounting tasks';
COMMENT ON COLUMN receiving_records.purchasing_manager_user_id IS 'Selected purchasing manager or responsible user for purchasing oversight';
COMMENT ON COLUMN receiving_records.expired_return_amount IS 'Amount returned for expired items';
COMMENT ON COLUMN receiving_records.near_expiry_return_amount IS 'Amount returned for near expiry items';
COMMENT ON COLUMN receiving_records.over_stock_return_amount IS 'Amount returned for over stock items';
COMMENT ON COLUMN receiving_records.damage_return_amount IS 'Amount returned for damaged items';
COMMENT ON COLUMN receiving_records.total_return_amount IS 'Total amount of all returns (auto-calculated)';
COMMENT ON COLUMN receiving_records.final_bill_amount IS 'Final bill amount after deducting returns (auto-calculated)';
COMMENT ON COLUMN receiving_records.expired_erp_document_type IS 'ERP document type for expired returns (GRN, PR)';
COMMENT ON COLUMN receiving_records.expired_erp_document_number IS 'ERP document number for expired returns';
COMMENT ON COLUMN receiving_records.expired_vendor_document_number IS 'Vendor document number for expired returns';
COMMENT ON COLUMN receiving_records.near_expiry_erp_document_type IS 'ERP document type for near expiry returns (GRN, PR)';
COMMENT ON COLUMN receiving_records.near_expiry_erp_document_number IS 'ERP document number for near expiry returns';
COMMENT ON COLUMN receiving_records.near_expiry_vendor_document_number IS 'Vendor document number for near expiry returns';
COMMENT ON COLUMN receiving_records.over_stock_erp_document_type IS 'ERP document type for over stock returns (GRN, PR)';
COMMENT ON COLUMN receiving_records.over_stock_erp_document_number IS 'ERP document number for over stock returns';
COMMENT ON COLUMN receiving_records.over_stock_vendor_document_number IS 'Vendor document number for over stock returns';
COMMENT ON COLUMN receiving_records.damage_erp_document_type IS 'ERP document type for damage returns (GRN, PR)';
COMMENT ON COLUMN receiving_records.damage_erp_document_number IS 'ERP document number for damage returns';
COMMENT ON COLUMN receiving_records.damage_vendor_document_number IS 'Vendor document number for damage returns';
COMMENT ON COLUMN receiving_records.has_expired_returns IS 'Whether expired returns were processed';
COMMENT ON COLUMN receiving_records.has_near_expiry_returns IS 'Whether near expiry returns were processed';
COMMENT ON COLUMN receiving_records.has_over_stock_returns IS 'Whether over stock returns were processed';
COMMENT ON COLUMN receiving_records.has_damage_returns IS 'Whether damage returns were processed';
COMMENT ON COLUMN receiving_records.created_at IS 'When this receiving record was created in system';