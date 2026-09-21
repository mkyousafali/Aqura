ALTER TABLE public.aqura_pos_print_actions
  ADD COLUMN IF NOT EXISTS pos_counter_id integer,
  ADD COLUMN IF NOT EXISTS pos_counter_name text,
  ADD COLUMN IF NOT EXISTS pos_counter_number text;
