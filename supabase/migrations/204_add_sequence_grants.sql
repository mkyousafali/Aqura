-- Add missing sequence grants for approver tables (fixing permission denied errors)

-- Grant access to approver_visibility_config sequence
GRANT ALL ON public.approver_visibility_config_id_seq TO anon;
GRANT ALL ON public.approver_visibility_config_id_seq TO authenticated;
GRANT ALL ON public.approver_visibility_config_id_seq TO service_role;

-- Grant access to approver_branch_access sequence
GRANT ALL ON public.approver_branch_access_id_seq TO anon;
GRANT ALL ON public.approver_branch_access_id_seq TO authenticated;
GRANT ALL ON public.approver_branch_access_id_seq TO service_role;
