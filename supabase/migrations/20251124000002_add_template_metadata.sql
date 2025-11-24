-- Add metadata column to shelf_paper_templates table
ALTER TABLE shelf_paper_templates 
ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT NULL;

COMMENT ON COLUMN shelf_paper_templates.metadata IS 'Stores template metadata like preview dimensions used for field positioning';
