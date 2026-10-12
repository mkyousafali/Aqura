begin;

create table if not exists public.erp_posting_ledger_links (
    id uuid primary key default gen_random_uuid(),
    branch_id bigint not null references public.branches(id) on delete cascade,
    account_key text not null check (account_key in ('branch_cash', 'pos_cash', 'pos_bank', 'pos_short', 'pos_excess')),
    pos_number integer,
    erp_ledger_id bigint,
    ledger_code text not null,
    ledger_name text not null,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint erp_posting_ledger_links_pos_check check (
        (account_key = 'pos_cash' and pos_number is not null and pos_number > 0)
        or (account_key <> 'pos_cash' and pos_number is null)
    )
);

create unique index if not exists erp_posting_ledger_links_account_uidx
    on public.erp_posting_ledger_links (branch_id, account_key, coalesce(pos_number, 0));

create index if not exists erp_posting_ledger_links_branch_idx
    on public.erp_posting_ledger_links (branch_id);

create or replace function public.touch_erp_posting_ledger_links_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

drop trigger if exists erp_posting_ledger_links_updated_at on public.erp_posting_ledger_links;
create trigger erp_posting_ledger_links_updated_at
before update on public.erp_posting_ledger_links
for each row execute function public.touch_erp_posting_ledger_links_updated_at();

alter table public.erp_posting_ledger_links enable row level security;

drop policy if exists "Allow anon full access to erp_posting_ledger_links" on public.erp_posting_ledger_links;
create policy "Allow anon full access to erp_posting_ledger_links"
on public.erp_posting_ledger_links for all to anon using (true) with check (true);

drop policy if exists "Allow authenticated full access to erp_posting_ledger_links" on public.erp_posting_ledger_links;
create policy "Allow authenticated full access to erp_posting_ledger_links"
on public.erp_posting_ledger_links for all to authenticated using (true) with check (true);

grant all on table public.erp_posting_ledger_links to anon, authenticated, service_role;

commit;
