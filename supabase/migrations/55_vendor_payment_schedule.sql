-- Create vendor payment schedule table
CREATE TABLE IF NOT EXISTS vendor_payment_schedule (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    receiving_record_id UUID REFERENCES receiving_records(id) ON DELETE CASCADE,
    bill_number VARCHAR(255),
    vendor_id VARCHAR(255),
    vendor_name VARCHAR(255),
    branch_id INTEGER REFERENCES branches(id),
    branch_name VARCHAR(255),
    bill_date DATE,
    bill_amount DECIMAL(15,2),
    final_bill_amount DECIMAL(15,2),
    payment_method VARCHAR(100),
    bank_name VARCHAR(255),
    iban VARCHAR(255),
    due_date DATE,
    credit_period INTEGER,
    vat_number VARCHAR(100),
    payment_status VARCHAR(50) DEFAULT 'scheduled',
    scheduled_date TIMESTAMP DEFAULT NOW(),
    paid_date TIMESTAMP,
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_vendor_payment_schedule_receiving_record_id ON vendor_payment_schedule(receiving_record_id);
CREATE INDEX IF NOT EXISTS idx_vendor_payment_schedule_vendor_id ON vendor_payment_schedule(vendor_id);
CREATE INDEX IF NOT EXISTS idx_vendor_payment_schedule_due_date ON vendor_payment_schedule(due_date);
CREATE INDEX IF NOT EXISTS idx_vendor_payment_schedule_payment_status ON vendor_payment_schedule(payment_status);
CREATE INDEX IF NOT EXISTS idx_vendor_payment_schedule_branch_id ON vendor_payment_schedule(branch_id);

-- Enable RLS (Row Level Security)
ALTER TABLE vendor_payment_schedule ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view vendor payment schedule" ON vendor_payment_schedule;
DROP POLICY IF EXISTS "Users can insert vendor payment schedule" ON vendor_payment_schedule;
DROP POLICY IF EXISTS "Users can update vendor payment schedule" ON vendor_payment_schedule;
DROP POLICY IF EXISTS "Users can delete vendor payment schedule" ON vendor_payment_schedule;

-- Create policy for authenticated users (allow all operations for authenticated users)
CREATE POLICY "Users can view vendor payment schedule" ON vendor_payment_schedule
    FOR SELECT USING (true);

CREATE POLICY "Users can insert vendor payment schedule" ON vendor_payment_schedule
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Users can update vendor payment schedule" ON vendor_payment_schedule
    FOR UPDATE USING (true);

CREATE POLICY "Users can delete vendor payment schedule" ON vendor_payment_schedule
    FOR DELETE USING (true);

-- Create trigger for updated_at
CREATE OR REPLACE FUNCTION update_vendor_payment_schedule_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create function to auto-schedule payments when certificate is generated
CREATE OR REPLACE FUNCTION auto_schedule_payment_on_certificate_generation()
RETURNS TRIGGER AS $$
BEGIN
    -- Only trigger when certificate is generated (certificate_url changes from NULL to something)
    -- or certificate_generated_at is updated
    IF (OLD.certificate_url IS NULL AND NEW.certificate_url IS NOT NULL)
       OR (OLD.certificate_generated_at IS NULL AND NEW.certificate_generated_at IS NOT NULL)
       OR (NEW.certificate_generated_at IS NOT NULL AND NEW.certificate_generated_at != OLD.certificate_generated_at) THEN
        
        -- Only auto-schedule if:
        -- 1. Payment method is set
        -- 2. Due date is set  
        -- 3. Bill amount is greater than 0
        -- 4. Not already scheduled
        -- 5. Certificate was just generated
        IF NEW.payment_method IS NOT NULL 
           AND NEW.due_date IS NOT NULL 
           AND NEW.bill_amount > 0 
           AND NOT EXISTS (
               SELECT 1 FROM vendor_payment_schedule 
               WHERE receiving_record_id = NEW.id
           ) THEN
            
            -- Insert into payment schedule
            INSERT INTO vendor_payment_schedule (
                receiving_record_id,
                bill_number,
                vendor_id,
                vendor_name,
                branch_id,
                branch_name,
                bill_date,
                bill_amount,
                final_bill_amount,
                payment_method,
                bank_name,
                iban,
                due_date,
                credit_period,
                vat_number,
                payment_status,
                scheduled_date,
                notes
            )
            SELECT 
                NEW.id,
                NEW.bill_number,
                NEW.vendor_id::VARCHAR,
                v.vendor_name,
                NEW.branch_id,
                b.name_en,
                NEW.bill_date,
                NEW.bill_amount,
                COALESCE(NEW.final_bill_amount, NEW.bill_amount),
                NEW.payment_method,
                NEW.bank_name,
                NEW.iban,
                NEW.due_date,
                NEW.credit_period,
                NEW.vendor_vat_number,
                'scheduled',
                NOW(),
                'Auto-scheduled when certificate was generated in receiving process'
            FROM branches b
            LEFT JOIN vendors v ON v.erp_vendor_id = NEW.vendor_id::VARCHAR AND v.branch_id = NEW.branch_id
            WHERE b.id = NEW.branch_id;
            
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Drop existing triggers if they exist
DROP TRIGGER IF EXISTS update_vendor_payment_schedule_updated_at ON vendor_payment_schedule;
DROP TRIGGER IF EXISTS auto_schedule_payment_on_certificate_trigger ON receiving_records;

-- Create triggers
CREATE TRIGGER update_vendor_payment_schedule_updated_at
    BEFORE UPDATE ON vendor_payment_schedule
    FOR EACH ROW
    EXECUTE FUNCTION update_vendor_payment_schedule_updated_at();

-- Create trigger on receiving_records to auto-schedule payments when certificate is generated
CREATE TRIGGER auto_schedule_payment_on_certificate_trigger
    AFTER UPDATE ON receiving_records
    FOR EACH ROW
    EXECUTE FUNCTION auto_schedule_payment_on_certificate_generation();

-- Add comments for documentation
COMMENT ON TABLE vendor_payment_schedule IS 'Schedule and track vendor payments';
COMMENT ON COLUMN vendor_payment_schedule.payment_status IS 'Payment status: scheduled, paid, cancelled, overdue';
COMMENT ON COLUMN vendor_payment_schedule.scheduled_date IS 'When the payment was scheduled';
COMMENT ON COLUMN vendor_payment_schedule.paid_date IS 'When the payment was actually made';