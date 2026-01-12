-- Add 'petty_cash_box' record type to denomination_records constraint
ALTER TABLE public.denomination_records
DROP CONSTRAINT denomination_records_record_type_check;

ALTER TABLE public.denomination_records
ADD CONSTRAINT denomination_records_record_type_check CHECK (
  record_type = ANY (ARRAY['main', 'advance_box', 'collection_box', 'paid', 'received', 'petty_cash_box'])
);

-- Add comment explaining the new type
COMMENT ON CONSTRAINT denomination_records_record_type_check ON public.denomination_records IS 
'Allowed record types: main (main denomination), advance_box (advance manager boxes), collection_box (collection boxes), paid (paid records), received (received records), petty_cash_box (petty cash transfers)';
