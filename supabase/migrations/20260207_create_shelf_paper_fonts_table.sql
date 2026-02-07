-- Create shelf_paper_fonts table
-- Stores metadata for custom fonts uploaded for shelf paper templates

CREATE TABLE IF NOT EXISTS shelf_paper_fonts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  font_url TEXT NOT NULL,
  file_name VARCHAR(255),
  file_size INTEGER,
  created_by UUID,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_shelf_paper_fonts_name ON shelf_paper_fonts(name);
CREATE INDEX IF NOT EXISTS idx_shelf_paper_fonts_created_by ON shelf_paper_fonts(created_by);
