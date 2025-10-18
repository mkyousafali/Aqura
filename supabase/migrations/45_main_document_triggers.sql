-- Create triggers to automatically populate main document columns
-- This ensures the dedicated columns are always in sync with the document records

-- Function to update main document columns
CREATE OR REPLACE FUNCTION update_main_document_columns()
RETURNS TRIGGER AS $$
BEGIN
    -- Update the dedicated columns based on document type
    IF NEW.document_type = 'health_card' THEN
        NEW.health_card_number := NEW.document_number;
        NEW.health_card_expiry := NEW.expiry_date;
    ELSIF NEW.document_type = 'resident_id' THEN
        NEW.resident_id_number := NEW.document_number;
        NEW.resident_id_expiry := NEW.expiry_date;
    ELSIF NEW.document_type = 'passport' THEN
        NEW.passport_number := NEW.document_number;
        NEW.passport_expiry := NEW.expiry_date;
    ELSIF NEW.document_type = 'driving_license' THEN
        NEW.driving_license_number := NEW.document_number;
        NEW.driving_license_expiry := NEW.expiry_date;
    ELSIF NEW.document_type = 'resume' THEN
        NEW.resume_uploaded := TRUE;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to clear main document columns when document is deleted or deactivated
CREATE OR REPLACE FUNCTION clear_main_document_columns()
RETURNS TRIGGER AS $$
BEGIN
    -- Clear the dedicated columns based on document type
    IF OLD.document_type = 'health_card' THEN
        OLD.health_card_number := NULL;
        OLD.health_card_expiry := NULL;
    ELSIF OLD.document_type = 'resident_id' THEN
        OLD.resident_id_number := NULL;
        OLD.resident_id_expiry := NULL;
    ELSIF OLD.document_type = 'passport' THEN
        OLD.passport_number := NULL;
        OLD.passport_expiry := NULL;
    ELSIF OLD.document_type = 'driving_license' THEN
        OLD.driving_license_number := NULL;
        OLD.driving_license_expiry := NULL;
    ELSIF OLD.document_type = 'resume' THEN
        OLD.resume_uploaded := FALSE;
    END IF;
    
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- Create triggers
CREATE TRIGGER trigger_update_main_document_columns
    BEFORE INSERT OR UPDATE ON hr_employee_documents
    FOR EACH ROW
    EXECUTE FUNCTION update_main_document_columns();

CREATE TRIGGER trigger_clear_main_document_columns
    BEFORE DELETE ON hr_employee_documents
    FOR EACH ROW
    EXECUTE FUNCTION clear_main_document_columns();

-- Create trigger for when is_active is set to false
CREATE OR REPLACE FUNCTION handle_document_deactivation()
RETURNS TRIGGER AS $$
BEGIN
    -- If document is being deactivated, clear the main document columns
    IF OLD.is_active = TRUE AND NEW.is_active = FALSE THEN
        IF NEW.document_type = 'health_card' THEN
            NEW.health_card_number := NULL;
            NEW.health_card_expiry := NULL;
        ELSIF NEW.document_type = 'resident_id' THEN
            NEW.resident_id_number := NULL;
            NEW.resident_id_expiry := NULL;
        ELSIF NEW.document_type = 'passport' THEN
            NEW.passport_number := NULL;
            NEW.passport_expiry := NULL;
        ELSIF NEW.document_type = 'driving_license' THEN
            NEW.driving_license_number := NULL;
            NEW.driving_license_expiry := NULL;
        ELSIF NEW.document_type = 'resume' THEN
            NEW.resume_uploaded := FALSE;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_handle_document_deactivation
    BEFORE UPDATE ON hr_employee_documents
    FOR EACH ROW
    EXECUTE FUNCTION handle_document_deactivation();

-- Add success notice
DO $$ 
BEGIN 
    RAISE NOTICE 'Created triggers for main document column synchronization';
END $$;