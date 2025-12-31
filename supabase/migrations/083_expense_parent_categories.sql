-- Expense Parent Categories Table Schema
CREATE TABLE IF NOT EXISTS expense_parent_categories (
  id INTEGER PRIMARY KEY DEFAULT nextval('expense_parent_categories_id_seq'),
  category_name VARCHAR NOT NULL UNIQUE,
  category_code VARCHAR NOT NULL UNIQUE,
  description TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
