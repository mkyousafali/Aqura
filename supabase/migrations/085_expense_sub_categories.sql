-- Expense Sub Categories Table Schema
CREATE TABLE IF NOT EXISTS expense_sub_categories (
  id INTEGER PRIMARY KEY DEFAULT nextval('expense_sub_categories_id_seq'),
  parent_category_id INTEGER NOT NULL,
  sub_category_name VARCHAR NOT NULL,
  sub_category_code VARCHAR NOT NULL,
  description TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
