-- Task Images Table Schema
CREATE TABLE IF NOT EXISTS task_images (
  id INTEGER PRIMARY KEY DEFAULT nextval('task_images_id_seq'),
  task_id INTEGER NOT NULL,
  image_url VARCHAR NOT NULL,
  image_title VARCHAR,
  image_description TEXT,
  uploaded_by UUID,
  uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  is_main_image BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
