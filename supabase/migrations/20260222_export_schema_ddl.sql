-- ═══════════════════════════════════════════════════════════════════
-- RPC: export_schema_ddl()
-- Returns SQL DDL for ALL public functions, triggers, types, and policies
-- Used by branch sync to auto-deploy schema changes without SSH/pg_dump
-- ═══════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.export_schema_ddl()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_functions text := '';
    v_triggers text := '';
    v_types text := '';
    v_policies text := '';
    v_grants text := '';
    v_tables text := '';
    v_indexes text := '';
    v_sequences text := '';
    v_columns text := '';
    r record;
BEGIN
    -- ═══ SEQUENCES ═══
    -- Export all sequences in public schema (must come before tables that reference them)
    FOR r IN
        SELECT c.relname AS seq_name,
               s.seqtypid,
               pg_catalog.format_type(s.seqtypid, NULL) AS seq_type,
               s.seqstart, s.seqincrement, s.seqmin, s.seqmax, s.seqcache, s.seqcycle
        FROM pg_class c
        JOIN pg_namespace n ON c.relnamespace = n.oid
        JOIN pg_sequence s ON s.seqrelid = c.oid
        WHERE n.nspname = 'public'
          AND c.relkind = 'S' -- sequences
        ORDER BY c.relname
    LOOP
        v_sequences := v_sequences || format(
            'CREATE SEQUENCE IF NOT EXISTS public.%I AS %s INCREMENT BY %s MINVALUE %s MAXVALUE %s START WITH %s CACHE %s%s;',
            r.seq_name, r.seq_type, r.seqincrement, r.seqmin, r.seqmax, r.seqstart, r.seqcache,
            CASE WHEN r.seqcycle THEN ' CYCLE' ELSE '' END
        ) || E'\n';
        v_sequences := v_sequences || format(
            'GRANT USAGE, SELECT ON SEQUENCE public.%I TO authenticated, anon, service_role;',
            r.seq_name
        ) || E'\n';
    END LOOP;

    -- ═══ FUNCTIONS ═══
    -- Export all user-defined functions in public schema
    -- Use DROP + CREATE to handle return type changes (CREATE OR REPLACE can't change return type)
    FOR r IN
        SELECT p.oid, p.proname,
               pg_get_functiondef(p.oid) AS funcdef,
               pg_get_function_identity_arguments(p.oid) AS identity_args,
               p.prokind
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public'
          AND p.prokind IN ('f', 'p') -- functions and procedures
        ORDER BY p.proname
    LOOP
        -- DROP first to handle return type changes
        IF r.prokind = 'p' THEN
            v_functions := v_functions || format(
                'DROP PROCEDURE IF EXISTS public.%I(%s) CASCADE;',
                r.proname, r.identity_args
            ) || E'\n';
        ELSE
            v_functions := v_functions || format(
                'DROP FUNCTION IF EXISTS public.%I(%s) CASCADE;',
                r.proname, r.identity_args
            ) || E'\n';
        END IF;
        v_functions := v_functions || r.funcdef || ';' || E'\n\n';
        -- Add grants for each function
        v_grants := v_grants || format(
            'GRANT EXECUTE ON FUNCTION public.%I TO authenticated, anon, service_role;',
            r.proname
        ) || E'\n';
    END LOOP;

    -- ═══ CUSTOM TYPES (enums and composites) ═══
    FOR r IN
        SELECT t.typname,
               CASE t.typtype
                   WHEN 'e' THEN
                       'CREATE TYPE IF NOT EXISTS public.' || quote_ident(t.typname) || ' AS ENUM (' ||
                       string_agg(quote_literal(e.enumlabel), ', ' ORDER BY e.enumsortorder) || ')'
                   WHEN 'c' THEN
                       'DO $typchk$ BEGIN CREATE TYPE public.' || quote_ident(t.typname) || ' AS (' ||
                       string_agg(quote_ident(a.attname) || ' ' || pg_catalog.format_type(a.atttypid, a.atttypmod), ', ' ORDER BY a.attnum) ||
                       '); EXCEPTION WHEN duplicate_object THEN NULL; END $typchk$'
               END AS typedef
        FROM pg_type t
        JOIN pg_namespace n ON t.typnamespace = n.oid
        LEFT JOIN pg_enum e ON t.typtype = 'e' AND e.enumtypid = t.oid
        LEFT JOIN pg_attribute a ON t.typtype = 'c' AND a.attrelid = t.typrelid AND a.attnum > 0
        WHERE n.nspname = 'public'
          AND t.typtype IN ('e', 'c')
          AND t.typname NOT LIKE 'pg_%'
          AND t.typname NOT LIKE '_%' -- skip internal composite types for tables
        GROUP BY t.typname, t.typtype
        ORDER BY t.typtype DESC, t.typname -- enums first, then composites
    LOOP
        IF r.typedef IS NOT NULL THEN
            v_types := v_types || r.typedef || ';' || E'\n';
        END IF;
    END LOOP;

    -- ═══ TABLES (CREATE TABLE IF NOT EXISTS) ═══
    -- Export all public tables with columns, defaults, NOT NULL, and primary keys
    FOR r IN
        SELECT c.relname AS table_name,
               c.oid AS table_oid,
               c.relrowsecurity AS rls_enabled
        FROM pg_class c
        JOIN pg_namespace n ON c.relnamespace = n.oid
        WHERE n.nspname = 'public'
          AND c.relkind = 'r' -- regular tables only
        ORDER BY c.relname
    LOOP
        DECLARE
            v_cols text := '';
            v_pk text := '';
            v_constraints text := '';
            col record;
            con record;
            idx record;
        BEGIN
            -- Columns
            FOR col IN
                SELECT a.attname,
                       pg_catalog.format_type(a.atttypid, a.atttypmod) AS col_type,
                       a.attnotnull AS not_null,
                       pg_get_expr(d.adbin, d.adrelid) AS default_val,
                       a.attidentity
                FROM pg_attribute a
                LEFT JOIN pg_attrdef d ON a.attrelid = d.adrelid AND a.attnum = d.adnum
                WHERE a.attrelid = r.table_oid
                  AND a.attnum > 0
                  AND NOT a.attisdropped
                ORDER BY a.attnum
            LOOP
                IF v_cols != '' THEN v_cols := v_cols || ',' || E'\n'; END IF;
                v_cols := v_cols || '    ' || quote_ident(col.attname) || ' ' || col.col_type;
                IF col.attidentity = 'a' THEN
                    v_cols := v_cols || ' GENERATED ALWAYS AS IDENTITY';
                ELSIF col.attidentity = 'd' THEN
                    v_cols := v_cols || ' GENERATED BY DEFAULT AS IDENTITY';
                ELSIF col.default_val IS NOT NULL THEN
                    v_cols := v_cols || ' DEFAULT ' || col.default_val;
                END IF;
                IF col.not_null THEN
                    v_cols := v_cols || ' NOT NULL';
                END IF;
            END LOOP;

            -- Primary key and unique constraints
            FOR con IN
                SELECT pg_get_constraintdef(c2.oid) AS condef,
                       c2.conname,
                       c2.contype
                FROM pg_constraint c2
                WHERE c2.conrelid = r.table_oid
                  AND c2.contype IN ('p', 'u', 'f', 'c') -- PK, unique, FK, check
                ORDER BY c2.contype, c2.conname
            LOOP
                v_constraints := v_constraints || ',' || E'\n' || '    CONSTRAINT ' || quote_ident(con.conname) || ' ' || con.condef;
            END LOOP;

            v_tables := v_tables || 'CREATE TABLE IF NOT EXISTS public.' || quote_ident(r.table_name) || ' (' || E'\n';
            v_tables := v_tables || v_cols || v_constraints || E'\n);\n';

            -- Enable RLS if enabled on source
            IF r.rls_enabled THEN
                v_tables := v_tables || 'ALTER TABLE public.' || quote_ident(r.table_name) || ' ENABLE ROW LEVEL SECURITY;' || E'\n';
            END IF;

            -- Grant table permissions
            v_tables := v_tables || 'GRANT ALL ON public.' || quote_ident(r.table_name) || ' TO authenticated, anon, service_role;' || E'\n\n';

            -- ALTER TABLE ADD COLUMN IF NOT EXISTS for each column (handles missing columns on existing tables)
            FOR col IN
                SELECT a.attname,
                       pg_catalog.format_type(a.atttypid, a.atttypmod) AS col_type,
                       pg_get_expr(d.adbin, d.adrelid) AS default_val,
                       a.attidentity
                FROM pg_attribute a
                LEFT JOIN pg_attrdef d ON a.attrelid = d.adrelid AND a.attnum = d.adnum
                WHERE a.attrelid = r.table_oid
                  AND a.attnum > 0
                  AND NOT a.attisdropped
                ORDER BY a.attnum
            LOOP
                -- Skip identity columns in ADD COLUMN (they need special handling)
                IF col.attidentity IN ('a', 'd') THEN
                    CONTINUE;
                END IF;
                v_columns := v_columns || 'ALTER TABLE public.' || quote_ident(r.table_name) || ' ADD COLUMN IF NOT EXISTS ' || quote_ident(col.attname) || ' ' || col.col_type;
                IF col.default_val IS NOT NULL THEN
                    v_columns := v_columns || ' DEFAULT ' || col.default_val;
                END IF;
                v_columns := v_columns || ';' || E'\n';
            END LOOP;

            -- Indexes (non-primary, non-unique-constraint)
            FOR idx IN
                SELECT pg_get_indexdef(i.indexrelid) AS indexdef
                FROM pg_index i
                JOIN pg_class ic ON i.indexrelid = ic.oid
                WHERE i.indrelid = r.table_oid
                  AND NOT i.indisprimary
                  AND NOT EXISTS (
                      SELECT 1 FROM pg_constraint WHERE conindid = i.indexrelid
                  )
            LOOP
                -- Add IF NOT EXISTS to CREATE INDEX / CREATE UNIQUE INDEX statements
                v_indexes := v_indexes || replace(replace(idx.indexdef, 'CREATE UNIQUE INDEX ', 'CREATE UNIQUE INDEX IF NOT EXISTS '), 'CREATE INDEX ', 'CREATE INDEX IF NOT EXISTS ') || ';' || E'\n';
            END LOOP;
        END;
    END LOOP;

    -- ═══ TRIGGERS ═══
    FOR r IN
        SELECT tg.tgname AS trigger_name,
               c.relname AS table_name,
               pg_get_triggerdef(tg.oid) AS triggerdef
        FROM pg_trigger tg
        JOIN pg_class c ON tg.tgrelid = c.oid
        JOIN pg_namespace n ON c.relnamespace = n.oid
        WHERE n.nspname = 'public'
          AND NOT tg.tgisinternal
        ORDER BY c.relname, tg.tgname
    LOOP
        -- DROP + CREATE to handle changes
        v_triggers := v_triggers || format(
            'DROP TRIGGER IF EXISTS %I ON public.%I;',
            r.trigger_name, r.table_name
        ) || E'\n';
        v_triggers := v_triggers || r.triggerdef || ';' || E'\n\n';
    END LOOP;

    -- ═══ RLS POLICIES ═══
    FOR r IN
        SELECT schemaname, tablename, policyname,
               permissive, roles, cmd, qual, with_check
        FROM pg_policies
        WHERE schemaname = 'public'
        ORDER BY tablename, policyname
    LOOP
        v_policies := v_policies || format(
            'DROP POLICY IF EXISTS %I ON public.%I;',
            r.policyname, r.tablename
        ) || E'\n';
        v_policies := v_policies || format(
            'CREATE POLICY %I ON public.%I AS %s FOR %s TO %s',
            r.policyname, r.tablename,
            r.permissive,
            r.cmd,
            array_to_string(r.roles, ', ')
        );
        IF r.qual IS NOT NULL THEN
            v_policies := v_policies || ' USING (' || r.qual || ')';
        END IF;
        IF r.with_check IS NOT NULL THEN
            v_policies := v_policies || ' WITH CHECK (' || r.with_check || ')';
        END IF;
        v_policies := v_policies || ';' || E'\n\n';
    END LOOP;

    RETURN jsonb_build_object(
        'sequences', v_sequences,
        'tables', v_tables,
        'columns', v_columns,
        'indexes', v_indexes,
        'types', v_types,
        'functions', v_functions,
        'triggers', v_triggers,
        'policies', v_policies,
        'grants', v_grants,
        'exported_at', now()::text,
        'table_count', (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON c.relnamespace = n.oid WHERE n.nspname = 'public' AND c.relkind = 'r'),
        'function_count', (SELECT count(*) FROM pg_proc WHERE pronamespace = 'public'::regnamespace),
        'trigger_count', (SELECT count(*) FROM pg_trigger tg JOIN pg_class c ON tg.tgrelid = c.oid JOIN pg_namespace n ON c.relnamespace = n.oid WHERE n.nspname = 'public' AND NOT tg.tgisinternal),
        'type_count', (SELECT count(*) FROM pg_type WHERE typnamespace = 'public'::regnamespace AND typtype IN ('e','c') AND typname NOT LIKE 'pg_%' AND typname NOT LIKE '_%'),
        'policy_count', (SELECT count(*) FROM pg_policies WHERE schemaname = 'public'),
        'sequence_count', (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON c.relnamespace = n.oid WHERE n.nspname = 'public' AND c.relkind = 'S')
    );
END;
$$;

-- Grant access
GRANT EXECUTE ON FUNCTION public.export_schema_ddl() TO authenticated, service_role;

COMMENT ON FUNCTION public.export_schema_ddl() IS 'Exports all public schema DDL (functions, triggers, types, policies) as SQL text for branch sync';
