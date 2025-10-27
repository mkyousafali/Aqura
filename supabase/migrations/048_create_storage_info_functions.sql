-- Migration: Create Storage Information Functions
-- Description: Functions to retrieve storage bucket information, usage statistics, and connected tables
-- Date: 2025-10-27

-- =====================================================
-- Function: Get Storage Buckets Information
-- =====================================================
-- This function retrieves all storage buckets and their configuration
CREATE OR REPLACE FUNCTION get_storage_buckets_info()
RETURNS TABLE (
    id text,
    name text,
    owner uuid,
    public boolean,
    file_size_limit bigint,
    allowed_mime_types text[],
    created_at timestamptz,
    updated_at timestamptz,
    avif_autodetection boolean
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        b.id::text,
        b.name,
        b.owner,
        b.public,
        b.file_size_limit,
        b.allowed_mime_types,
        b.created_at,
        b.updated_at,
        b.avif_autodetection
    FROM storage.buckets b
    ORDER BY b.created_at DESC;
END;
$$;

COMMENT ON FUNCTION get_storage_buckets_info() IS 'Returns information about all storage buckets including configuration';

-- =====================================================
-- Function: Get Storage Objects Count by Bucket
-- =====================================================
-- This function returns the count of objects in each bucket
CREATE OR REPLACE FUNCTION get_storage_objects_count()
RETURNS TABLE (
    bucket_id text,
    bucket_name text,
    total_objects bigint,
    total_size_bytes bigint,
    total_size_mb numeric
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        o.bucket_id,
        b.name as bucket_name,
        COUNT(o.id)::bigint as total_objects,
        COALESCE(SUM(o.metadata->>'size')::bigint, 0) as total_size_bytes,
        ROUND(COALESCE(SUM((o.metadata->>'size')::bigint), 0) / 1024.0 / 1024.0, 2) as total_size_mb
    FROM storage.objects o
    INNER JOIN storage.buckets b ON o.bucket_id = b.id
    GROUP BY o.bucket_id, b.name
    ORDER BY total_size_bytes DESC;
END;
$$;

COMMENT ON FUNCTION get_storage_objects_count() IS 'Returns count and size of objects in each storage bucket';

-- =====================================================
-- Function: Get Storage Objects Details
-- =====================================================
-- This function retrieves detailed information about storage objects
CREATE OR REPLACE FUNCTION get_storage_objects_details(
    p_bucket_id text DEFAULT NULL,
    p_limit int DEFAULT 100,
    p_offset int DEFAULT 0
)
RETURNS TABLE (
    id uuid,
    bucket_id text,
    bucket_name text,
    name text,
    owner uuid,
    created_at timestamptz,
    updated_at timestamptz,
    last_accessed_at timestamptz,
    metadata jsonb,
    path_tokens text[],
    version text,
    file_size bigint,
    mime_type text
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        o.id,
        o.bucket_id,
        b.name as bucket_name,
        o.name,
        o.owner,
        o.created_at,
        o.updated_at,
        o.last_accessed_at,
        o.metadata,
        o.path_tokens,
        o.version,
        (o.metadata->>'size')::bigint as file_size,
        o.metadata->>'mimetype' as mime_type
    FROM storage.objects o
    INNER JOIN storage.buckets b ON o.bucket_id = b.id
    WHERE (p_bucket_id IS NULL OR o.bucket_id = p_bucket_id)
    ORDER BY o.created_at DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$$;

COMMENT ON FUNCTION get_storage_objects_details(text, int, int) IS 'Returns detailed information about storage objects with pagination';

-- =====================================================
-- Function: Get Connected Tables Information
-- =====================================================
-- This function retrieves all tables in the public schema with their metadata
CREATE OR REPLACE FUNCTION get_connected_tables_info()
RETURNS TABLE (
    table_schema text,
    table_name text,
    table_type text,
    row_count bigint,
    total_size text,
    table_size text,
    indexes_size text,
    has_primary_key boolean,
    created_at timestamptz
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        schemaname::text as table_schema,
        tablename::text as table_name,
        'BASE TABLE'::text as table_type,
        COALESCE(n_live_tup, 0)::bigint as row_count,
        pg_size_pretty(pg_total_relation_size(quote_ident(schemaname) || '.' || quote_ident(tablename))::bigint) as total_size,
        pg_size_pretty(pg_relation_size(quote_ident(schemaname) || '.' || quote_ident(tablename))::bigint) as table_size,
        pg_size_pretty(pg_total_relation_size(quote_ident(schemaname) || '.' || quote_ident(tablename))::bigint - 
                       pg_relation_size(quote_ident(schemaname) || '.' || quote_ident(tablename))::bigint) as indexes_size,
        EXISTS (
            SELECT 1 
            FROM pg_constraint 
            WHERE conrelid = (quote_ident(schemaname) || '.' || quote_ident(tablename))::regclass 
            AND contype = 'p'
        ) as has_primary_key,
        obj_description((quote_ident(schemaname) || '.' || quote_ident(tablename))::regclass, 'pg_class')::timestamptz as created_at
    FROM pg_stat_user_tables
    WHERE schemaname = 'public'
    ORDER BY pg_total_relation_size(quote_ident(schemaname) || '.' || quote_ident(tablename)) DESC;
END;
$$;

COMMENT ON FUNCTION get_connected_tables_info() IS 'Returns information about all tables in public schema including size and row count';

-- =====================================================
-- Function: Get Table Columns Information
-- =====================================================
-- This function retrieves column information for a specific table
CREATE OR REPLACE FUNCTION get_table_columns_info(p_table_name text)
RETURNS TABLE (
    column_name text,
    data_type text,
    is_nullable text,
    column_default text,
    character_maximum_length int,
    numeric_precision int,
    numeric_scale int,
    is_primary_key boolean,
    is_foreign_key boolean,
    foreign_table text,
    foreign_column text
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.column_name::text,
        c.data_type::text,
        c.is_nullable::text,
        c.column_default::text,
        c.character_maximum_length,
        c.numeric_precision,
        c.numeric_scale,
        EXISTS (
            SELECT 1 
            FROM information_schema.table_constraints tc
            JOIN information_schema.key_column_usage kcu 
                ON tc.constraint_name = kcu.constraint_name
            WHERE tc.table_name = p_table_name
            AND kcu.column_name = c.column_name
            AND tc.constraint_type = 'PRIMARY KEY'
        ) as is_primary_key,
        EXISTS (
            SELECT 1 
            FROM information_schema.table_constraints tc
            JOIN information_schema.key_column_usage kcu 
                ON tc.constraint_name = kcu.constraint_name
            WHERE tc.table_name = p_table_name
            AND kcu.column_name = c.column_name
            AND tc.constraint_type = 'FOREIGN KEY'
        ) as is_foreign_key,
        (
            SELECT ccu.table_name::text
            FROM information_schema.table_constraints tc
            JOIN information_schema.key_column_usage kcu 
                ON tc.constraint_name = kcu.constraint_name
            JOIN information_schema.constraint_column_usage ccu 
                ON tc.constraint_name = ccu.constraint_name
            WHERE tc.table_name = p_table_name
            AND kcu.column_name = c.column_name
            AND tc.constraint_type = 'FOREIGN KEY'
            LIMIT 1
        ) as foreign_table,
        (
            SELECT ccu.column_name::text
            FROM information_schema.table_constraints tc
            JOIN information_schema.key_column_usage kcu 
                ON tc.constraint_name = kcu.constraint_name
            JOIN information_schema.constraint_column_usage ccu 
                ON tc.constraint_name = ccu.constraint_name
            WHERE tc.table_name = p_table_name
            AND kcu.column_name = c.column_name
            AND tc.constraint_type = 'FOREIGN KEY'
            LIMIT 1
        ) as foreign_column
    FROM information_schema.columns c
    WHERE c.table_schema = 'public'
    AND c.table_name = p_table_name
    ORDER BY c.ordinal_position;
END;
$$;

COMMENT ON FUNCTION get_table_columns_info(text) IS 'Returns detailed column information for a specific table';

-- =====================================================
-- Function: Get Table Foreign Keys
-- =====================================================
-- This function retrieves all foreign key relationships for tables
CREATE OR REPLACE FUNCTION get_table_foreign_keys()
RETURNS TABLE (
    constraint_name text,
    table_schema text,
    table_name text,
    column_name text,
    foreign_table_schema text,
    foreign_table_name text,
    foreign_column_name text
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        tc.constraint_name::text,
        tc.table_schema::text,
        tc.table_name::text,
        kcu.column_name::text,
        ccu.table_schema::text as foreign_table_schema,
        ccu.table_name::text as foreign_table_name,
        ccu.column_name::text as foreign_column_name
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu 
        ON tc.constraint_name = kcu.constraint_name
        AND tc.table_schema = kcu.table_schema
    JOIN information_schema.constraint_column_usage ccu 
        ON tc.constraint_name = ccu.constraint_name
        AND tc.table_schema = ccu.table_schema
    WHERE tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_schema = 'public'
    ORDER BY tc.table_name, tc.constraint_name;
END;
$$;

COMMENT ON FUNCTION get_table_foreign_keys() IS 'Returns all foreign key relationships in public schema';

-- =====================================================
-- Function: Get Database Statistics Summary
-- =====================================================
-- This function returns overall database statistics
CREATE OR REPLACE FUNCTION get_database_statistics()
RETURNS TABLE (
    total_tables bigint,
    total_views bigint,
    total_functions bigint,
    total_storage_buckets bigint,
    total_storage_objects bigint,
    total_storage_size_mb numeric,
    database_size text
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE')::bigint as total_tables,
        (SELECT COUNT(*) FROM information_schema.views WHERE table_schema = 'public')::bigint as total_views,
        (SELECT COUNT(*) FROM information_schema.routines WHERE routine_schema = 'public')::bigint as total_functions,
        (SELECT COUNT(*) FROM storage.buckets)::bigint as total_storage_buckets,
        (SELECT COUNT(*) FROM storage.objects)::bigint as total_storage_objects,
        ROUND(COALESCE((SELECT SUM((metadata->>'size')::bigint) FROM storage.objects), 0) / 1024.0 / 1024.0, 2) as total_storage_size_mb,
        pg_size_pretty(pg_database_size(current_database())) as database_size;
END;
$$;

COMMENT ON FUNCTION get_database_statistics() IS 'Returns overall database and storage statistics';

-- =====================================================
-- Grant Permissions
-- =====================================================
-- Grant execute permissions on these functions to authenticated users
GRANT EXECUTE ON FUNCTION get_storage_buckets_info() TO authenticated;
GRANT EXECUTE ON FUNCTION get_storage_objects_count() TO authenticated;
GRANT EXECUTE ON FUNCTION get_storage_objects_details(text, int, int) TO authenticated;
GRANT EXECUTE ON FUNCTION get_connected_tables_info() TO authenticated;
GRANT EXECUTE ON FUNCTION get_table_columns_info(text) TO authenticated;
GRANT EXECUTE ON FUNCTION get_table_foreign_keys() TO authenticated;
GRANT EXECUTE ON FUNCTION get_database_statistics() TO authenticated;

-- Also grant to service_role for administrative access
GRANT EXECUTE ON FUNCTION get_storage_buckets_info() TO service_role;
GRANT EXECUTE ON FUNCTION get_storage_objects_count() TO service_role;
GRANT EXECUTE ON FUNCTION get_storage_objects_details(text, int, int) TO service_role;
GRANT EXECUTE ON FUNCTION get_connected_tables_info() TO service_role;
GRANT EXECUTE ON FUNCTION get_table_columns_info(text) TO service_role;
GRANT EXECUTE ON FUNCTION get_table_foreign_keys() TO service_role;
GRANT EXECUTE ON FUNCTION get_database_statistics() TO service_role;

-- =====================================================
-- Create View: Storage Overview
-- =====================================================
-- A convenient view for quick storage overview
CREATE OR REPLACE VIEW storage_overview AS
SELECT 
    b.id,
    b.name as bucket_name,
    b.public,
    b.file_size_limit,
    b.created_at,
    COUNT(o.id) as object_count,
    COALESCE(SUM((o.metadata->>'size')::bigint), 0) as total_bytes,
    pg_size_pretty(COALESCE(SUM((o.metadata->>'size')::bigint), 0)) as total_size
FROM storage.buckets b
LEFT JOIN storage.objects o ON b.id = o.bucket_id
GROUP BY b.id, b.name, b.public, b.file_size_limit, b.created_at
ORDER BY total_bytes DESC;

COMMENT ON VIEW storage_overview IS 'Quick overview of storage buckets with object counts and sizes';

-- Grant access to the view
GRANT SELECT ON storage_overview TO authenticated;
GRANT SELECT ON storage_overview TO service_role;
