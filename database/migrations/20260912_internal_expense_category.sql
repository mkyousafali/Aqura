BEGIN;

ALTER TABLE public.internal_expense_requests
  ADD COLUMN IF NOT EXISTS expense_category text,
  ADD COLUMN IF NOT EXISTS custom_expense_category text;

ALTER TABLE public.internal_expense_requests DROP CONSTRAINT IF EXISTS internal_expense_requests_expense_category_check;
ALTER TABLE public.internal_expense_requests ADD CONSTRAINT internal_expense_requests_expense_category_check CHECK (
  expense_category IS NULL OR expense_category IN (
    'Mess Room', 'Office', 'Cleaning', 'Guest', 'Cheese Section',
    'Vegetable Section', 'Bakery Section', 'Showroom', 'Other'
  )
);

ALTER TABLE public.internal_expense_requests DROP CONSTRAINT IF EXISTS internal_expense_requests_custom_category_check;
ALTER TABLE public.internal_expense_requests ADD CONSTRAINT internal_expense_requests_custom_category_check CHECK (
  expense_category IS NULL OR expense_category <> 'Other'
  OR nullif(btrim(custom_expense_category), '') IS NOT NULL
);

-- Make request creation and category persistence one atomic operation.
DROP FUNCTION IF EXISTS public.create_internal_expense_request(bigint, text, uuid, text, jsonb);

CREATE FUNCTION public.create_internal_expense_request(
  p_branch_id bigint,
  p_branch_name text,
  p_requester_id uuid,
  p_requester_name text,
  p_items jsonb,
  p_expense_category text,
  p_custom_expense_category text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  v_request_id bigint;
  v_item jsonb;
BEGIN
  IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
    RETURN json_build_object('success', false, 'error', 'At least one product is required');
  END IF;

  IF p_expense_category IS NULL OR p_expense_category NOT IN (
    'Mess Room', 'Office', 'Cleaning', 'Guest', 'Cheese Section',
    'Vegetable Section', 'Bakery Section', 'Showroom', 'Other'
  ) THEN
    RETURN json_build_object('success', false, 'error', 'Invalid expense category');
  END IF;

  IF p_expense_category = 'Other' AND nullif(btrim(p_custom_expense_category), '') IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Custom expense category is required');
  END IF;

  INSERT INTO public.internal_expense_requests (
    branch_id, branch_name, requester_id, requester_name, status,
    expense_category, custom_expense_category
  ) VALUES (
    p_branch_id, p_branch_name, p_requester_id, p_requester_name, 'requested',
    p_expense_category,
    CASE WHEN p_expense_category = 'Other' THEN btrim(p_custom_expense_category) ELSE NULL END
  ) RETURNING id INTO v_request_id;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    INSERT INTO public.internal_expense_request_items (request_id, photo_url, quantity)
    VALUES (v_request_id, v_item->>'photo_url', (v_item->>'quantity')::numeric);
  END LOOP;

  RETURN json_build_object('success', true, 'data', json_build_object('id', v_request_id));
END;
$function$;

COMMIT;
