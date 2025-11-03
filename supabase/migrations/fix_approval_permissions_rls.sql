-- =====================================================
-- Fix Approval Permissions RLS Policies
-- =====================================================
-- Purpose: Update RLS policies to work with custom authentication
-- Created: 2025-11-03
-- =====================================================

-- Drop existing policies
drop policy if exists "Users can view approval permissions" on public.approval_permissions;
drop policy if exists "Admins can manage approval permissions" on public.approval_permissions;

-- Create new policies that don't rely on auth.uid() (since using custom auth)
-- Allow all authenticated users to view all approval permissions
create policy "Allow all to view approval permissions"
  on public.approval_permissions
  for select
  using (true);

-- Allow Master Admins to manage (insert, update, delete)
create policy "Master Admins can manage approval permissions"
  on public.approval_permissions
  for all
  using (
    exists (
      select 1 from users
      where users.id = (current_setting('request.jwt.claims', true)::json->>'sub')::uuid
      and users.role_type = 'Master Admin'
    )
  )
  with check (
    exists (
      select 1 from users
      where users.id = (current_setting('request.jwt.claims', true)::json->>'sub')::uuid
      and users.role_type = 'Master Admin'
    )
  );

-- Log the change
do $$
begin
  raise notice 'RLS policies updated for approval_permissions table to work with custom authentication';
end $$;
