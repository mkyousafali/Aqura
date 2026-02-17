-- RPC function to get storage bucket statistics
-- Returns bucket name, file count, and total size for each bucket
CREATE OR REPLACE FUNCTION public.get_storage_stats()
RETURNS TABLE (
    bucket_id text,
    bucket_name text,
    file_count bigint,
    total_size bigint
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT 
        b.id::text AS bucket_id,
        b.name::text AS bucket_name,
        COALESCE(COUNT(o.id), 0) AS file_count,
        COALESCE(SUM((o.metadata->>'size')::bigint), 0) AS total_size
    FROM storage.buckets b
    LEFT JOIN storage.objects o ON o.bucket_id = b.id
    GROUP BY b.id, b.name
    ORDER BY total_size DESC;
$$;

-- Grant access to Supabase roles
GRANT EXECUTE ON FUNCTION public.get_storage_stats() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_storage_stats() TO anon;
GRANT EXECUTE ON FUNCTION public.get_storage_stats() TO service_role;
