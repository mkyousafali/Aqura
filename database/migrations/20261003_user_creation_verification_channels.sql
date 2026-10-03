begin;

alter table public.user_creation_verifications
  add column if not exists email_required boolean not null default true,
  add column if not exists whatsapp_required boolean not null default true;

comment on column public.user_creation_verifications.email_required is
  'Whether email OTP verification and credential delivery were selected for this session.';
comment on column public.user_creation_verifications.whatsapp_required is
  'Whether WhatsApp OTP verification and credential delivery were selected for this session.';

commit;
