-- Create nationalities table
CREATE TABLE IF NOT EXISTS nationalities (
  id VARCHAR(10) PRIMARY KEY,
  name_en VARCHAR(100) NOT NULL,
  name_ar VARCHAR(100) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Insert nationalities
INSERT INTO nationalities (id, name_en, name_ar) VALUES
('SA', 'Saudi Arabia', 'المملكة العربية السعودية'),
('EGY', 'Egypt', 'مصر'),
('YEM', 'Yemen', 'اليمن'),
('BAN', 'Bangladesh', 'بنغلاديش'),
('IND', 'India', 'الهند'),
('SUD', 'Sudan', 'السودان'),
('PHI', 'Philippines', 'الفلبين'),
('IDN', 'Indonesia', 'إندونيسيا'),
('PAK', 'Pakistan', 'باكستان'),
('LEB', 'Lebanon', 'لبنان'),
('ETH', 'Ethiopia', 'إثيوبيا')
ON CONFLICT (id) DO NOTHING;
