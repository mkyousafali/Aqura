-- Create app_functions table for managing application functions and features
-- This table stores function definitions, codes, and their active status

-- Create the app_functions table
CREATE TABLE IF NOT EXISTS public.app_functions (
    id UUID NOT NULL DEFAULT extensions.uuid_generate_v4(),
    function_name CHARACTER VARYING(100) NOT NULL,
    function_code CHARACTER VARYING(50) NOT NULL,
    description TEXT NULL,
    category CHARACTER VARYING(50) NULL,
    is_active BOOLEAN NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    
    CONSTRAINT app_functions_pkey PRIMARY KEY (id),
    CONSTRAINT app_functions_function_code_key UNIQUE (function_code),
    CONSTRAINT app_functions_function_name_key UNIQUE (function_name)
) TABLESPACE pg_default;

-- Create index for efficient queries on active functions
CREATE INDEX IF NOT EXISTS idx_app_functions_active 
ON public.app_functions USING btree (function_code) 
TABLESPACE pg_default
WHERE (is_active = true);

-- Create additional useful indexes
CREATE INDEX IF NOT EXISTS idx_app_functions_category 
ON public.app_functions (category) 
WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_app_functions_created_at 
ON public.app_functions (created_at DESC);

-- Create trigger to automatically update the updated_at column
-- Note: This assumes the update_updated_at_column() function already exists
DO $$ 
BEGIN
    -- Check if the update_updated_at_column function exists
    IF EXISTS (
        SELECT 1 FROM pg_proc 
        WHERE proname = 'update_updated_at_column'
    ) THEN
        -- Create the trigger
        CREATE TRIGGER update_app_functions_updated_at 
        BEFORE UPDATE ON app_functions 
        FOR EACH ROW 
        EXECUTE FUNCTION update_updated_at_column();
        
        RAISE NOTICE 'Created trigger update_app_functions_updated_at';
    ELSE
        RAISE WARNING 'Function update_updated_at_column() does not exist. Trigger not created.';
    END IF;
END $$;

-- Add table and column comments for documentation
COMMENT ON TABLE public.app_functions IS 'Stores application functions and features with their codes and active status';
COMMENT ON COLUMN public.app_functions.id IS 'Unique identifier for the function';
COMMENT ON COLUMN public.app_functions.function_name IS 'Human-readable name of the function';
COMMENT ON COLUMN public.app_functions.function_code IS 'Unique code identifier for the function';
COMMENT ON COLUMN public.app_functions.description IS 'Detailed description of the function';
COMMENT ON COLUMN public.app_functions.category IS 'Category grouping for the function';
COMMENT ON COLUMN public.app_functions.is_active IS 'Whether the function is currently active/enabled';
COMMENT ON COLUMN public.app_functions.created_at IS 'Timestamp when the function was created';
COMMENT ON COLUMN public.app_functions.updated_at IS 'Timestamp when the function was last updated';

-- Table and indexes created successfully
RAISE NOTICE 'app_functions table created with indexes and trigger';