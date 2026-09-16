begin;

update public.notifications n
set message_en=coalesce(n.message_en,n.message)||E'\n\nTask: '||coalesce(t.title_en,'')||E'\nVendor: '||coalesce(t.source_refs->>'vendor_name','')||E'\nBill number: '||coalesce(t.source_refs->>'bill_number','')||E'\nReceiving date: '||coalesce(t.source_refs->>'receiving_date','')||E'\nReceived by: '||coalesce(t.source_refs->>'received_by',''),
    message_ar=coalesce(n.message_ar,n.message)||E'\n\nالمهمة: '||coalesce(t.title_ar,'')||E'\nالمورد: '||coalesce(t.source_refs->>'vendor_name','')||E'\nرقم الفاتورة: '||coalesce(t.source_refs->>'bill_number','')||E'\nتاريخ الاستلام: '||coalesce(t.source_refs->>'receiving_date','')||E'\nتم الاستلام بواسطة: '||coalesce(t.source_refs->>'received_by',''),
    message=(coalesce(n.message_en,n.message)||E'\n\nTask: '||coalesce(t.title_en,'')||E'\nVendor: '||coalesce(t.source_refs->>'vendor_name','')||E'\nBill number: '||coalesce(t.source_refs->>'bill_number','')||E'\nReceiving date: '||coalesce(t.source_refs->>'receiving_date','')||E'\nReceived by: '||coalesce(t.source_refs->>'received_by',''))||E'\n---\n'||(coalesce(n.message_ar,n.message)||E'\n\nالمهمة: '||coalesce(t.title_ar,'')||E'\nالمورد: '||coalesce(t.source_refs->>'vendor_name','')||E'\nرقم الفاتورة: '||coalesce(t.source_refs->>'bill_number','')||E'\nتاريخ الاستلام: '||coalesce(t.source_refs->>'receiving_date','')||E'\nتم الاستلام بواسطة: '||coalesce(t.source_refs->>'received_by','')),
    metadata=n.metadata||jsonb_build_object('autotask_event_id',t.event_id,'autotask_notification_details_version',1),
    updated_at=now()
from public."Autotask_tasks" t
where n.metadata->>'autotask_id'=t.id::text
  and not n.metadata ? 'autotask_notification_details_version';

commit;
