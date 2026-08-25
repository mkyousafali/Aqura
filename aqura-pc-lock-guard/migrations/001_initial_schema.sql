-- Aqura PC Lock Guard — Database Migration
-- Creates all required tables for the Lock Guard system.

-- Devices table
CREATE TABLE IF NOT EXISTS public.lockguard_devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id TEXT NOT NULL UNIQUE,
    branch_id UUID REFERENCES public.branches(id),
    counter_id INTEGER,
    counter_name TEXT,
    hostname TEXT,
    os_version TEXT,
    ip_address TEXT,
    protection_state TEXT NOT NULL DEFAULT 'unconfigured',
    maintenance_mode BOOLEAN NOT NULL DEFAULT false,
    app_version TEXT,
    policy_version INTEGER NOT NULL DEFAULT 1,
    first_seen TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_seen TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_lockguard_devices_branch ON public.lockguard_devices(branch_id);
CREATE INDEX IF NOT EXISTS idx_lockguard_devices_state ON public.lockguard_devices(protection_state);

-- Heartbeats table
CREATE TABLE IF NOT EXISTS public.lockguard_heartbeats (
    id BIGSERIAL PRIMARY KEY,
    device_id TEXT NOT NULL,
    branch_id UUID REFERENCES public.branches(id),
    hostname TEXT,
    ip_address TEXT,
    protection_state TEXT,
    maintenance_mode BOOLEAN DEFAULT false,
    os_version TEXT,
    app_version TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_lockguard_heartbeats_device ON public.lockguard_heartbeats(device_id);
CREATE INDEX IF NOT EXISTS idx_lockguard_heartbeats_created ON public.lockguard_heartbeats(created_at DESC);

-- Events table
CREATE TABLE IF NOT EXISTS public.lockguard_events (
    id BIGSERIAL PRIMARY KEY,
    device_id TEXT NOT NULL,
    branch_id UUID REFERENCES public.branches(id),
    timestamp TIMESTAMPTZ NOT NULL DEFAULT now(),
    severity TEXT NOT NULL DEFAULT 'INFO',
    category TEXT NOT NULL,
    message TEXT NOT NULL,
    details JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_lockguard_events_device ON public.lockguard_events(device_id);
CREATE INDEX IF NOT EXISTS idx_lockguard_events_severity ON public.lockguard_events(severity);
CREATE INDEX IF NOT EXISTS idx_lockguard_events_created ON public.lockguard_events(created_at DESC);

-- Policies table
CREATE TABLE IF NOT EXISTS public.lockguard_policies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    policy_json JSONB NOT NULL DEFAULT '{}',
    version INTEGER NOT NULL DEFAULT 1,
    is_default BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Device-Policy assignments
CREATE TABLE IF NOT EXISTS public.lockguard_device_policies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id TEXT NOT NULL,
    policy_id UUID REFERENCES public.lockguard_policies(id),
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    assigned_by UUID
);

CREATE INDEX IF NOT EXISTS idx_lockguard_device_policies_device ON public.lockguard_device_policies(device_id);

-- App inventory (cloud copy)
CREATE TABLE IF NOT EXISTS public.lockguard_app_inventory (
    id BIGSERIAL PRIMARY KEY,
    device_id TEXT NOT NULL,
    branch_id UUID REFERENCES public.branches(id),
    name TEXT NOT NULL,
    path TEXT,
    publisher TEXT,
    version TEXT,
    hash TEXT,
    status TEXT NOT NULL DEFAULT 'unknown',
    first_seen TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_seen TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_lockguard_app_inv_device ON public.lockguard_app_inventory(device_id);

-- Allowed apps (global/branch-level)
CREATE TABLE IF NOT EXISTS public.lockguard_allowed_apps (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    publisher TEXT,
    path_pattern TEXT,
    branch_id UUID REFERENCES public.branches(id),
    is_global BOOLEAN NOT NULL DEFAULT false,
    approved_by UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Printer inventory (cloud copy)
CREATE TABLE IF NOT EXISTS public.lockguard_printer_inventory (
    id BIGSERIAL PRIMARY KEY,
    device_id TEXT NOT NULL,
    branch_id UUID REFERENCES public.branches(id),
    name TEXT NOT NULL,
    port TEXT,
    driver TEXT,
    status TEXT NOT NULL DEFAULT 'active',
    protected BOOLEAN NOT NULL DEFAULT false,
    first_seen TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_seen TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_lockguard_printer_inv_device ON public.lockguard_printer_inventory(device_id);

-- Maintenance sessions
CREATE TABLE IF NOT EXISTS public.lockguard_maintenance_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id TEXT NOT NULL,
    branch_id UUID REFERENCES public.branches(id),
    reason TEXT NOT NULL,
    started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    planned_end TIMESTAMPTZ,
    actual_end TIMESTAMPTZ,
    ended_by TEXT,
    status TEXT NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_lockguard_maint_device ON public.lockguard_maintenance_sessions(device_id);

-- Remote actions
CREATE TABLE IF NOT EXISTS public.lockguard_remote_actions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id TEXT NOT NULL,
    action TEXT NOT NULL,
    params JSONB,
    priority TEXT NOT NULL DEFAULT 'normal',
    status TEXT NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '1 hour'),
    received_at TIMESTAMPTZ,
    executed_at TIMESTAMPTZ,
    result JSONB,
    created_by UUID,
    nonce TEXT NOT NULL DEFAULT gen_random_uuid()::text
);

CREATE INDEX IF NOT EXISTS idx_lockguard_actions_device ON public.lockguard_remote_actions(device_id);
CREATE INDEX IF NOT EXISTS idx_lockguard_actions_status ON public.lockguard_remote_actions(status);
CREATE UNIQUE INDEX IF NOT EXISTS idx_lockguard_actions_nonce ON public.lockguard_remote_actions(nonce);

-- Enable RLS
ALTER TABLE public.lockguard_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lockguard_heartbeats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lockguard_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lockguard_policies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lockguard_device_policies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lockguard_app_inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lockguard_allowed_apps ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lockguard_printer_inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lockguard_maintenance_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lockguard_remote_actions ENABLE ROW LEVEL SECURITY;

-- RLS policies: service_role bypasses RLS, so these are for authenticated dashboard users
CREATE POLICY lockguard_devices_read ON public.lockguard_devices FOR SELECT TO authenticated USING (true);
CREATE POLICY lockguard_heartbeats_read ON public.lockguard_heartbeats FOR SELECT TO authenticated USING (true);
CREATE POLICY lockguard_events_read ON public.lockguard_events FOR SELECT TO authenticated USING (true);
CREATE POLICY lockguard_policies_all ON public.lockguard_policies FOR ALL TO authenticated USING (true);
CREATE POLICY lockguard_device_policies_all ON public.lockguard_device_policies FOR ALL TO authenticated USING (true);
CREATE POLICY lockguard_app_inventory_read ON public.lockguard_app_inventory FOR SELECT TO authenticated USING (true);
CREATE POLICY lockguard_allowed_apps_all ON public.lockguard_allowed_apps FOR ALL TO authenticated USING (true);
CREATE POLICY lockguard_printer_inventory_read ON public.lockguard_printer_inventory FOR SELECT TO authenticated USING (true);
CREATE POLICY lockguard_maintenance_sessions_read ON public.lockguard_maintenance_sessions FOR SELECT TO authenticated USING (true);
CREATE POLICY lockguard_remote_actions_all ON public.lockguard_remote_actions FOR ALL TO authenticated USING (true);

-- Heartbeat RPC function
CREATE OR REPLACE FUNCTION public.lockguard_heartbeat(
    p_device_id TEXT,
    p_branch_id UUID,
    p_hostname TEXT DEFAULT NULL,
    p_ip_address TEXT DEFAULT NULL,
    p_protection_state TEXT DEFAULT 'unknown',
    p_maintenance_mode BOOLEAN DEFAULT false,
    p_os_version TEXT DEFAULT NULL,
    p_app_version TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Upsert device record
    INSERT INTO public.lockguard_devices (device_id, branch_id, hostname, ip_address, protection_state, maintenance_mode, os_version, app_version, last_seen)
    VALUES (p_device_id, p_branch_id, p_hostname, p_ip_address, p_protection_state, p_maintenance_mode, p_os_version, p_app_version, now())
    ON CONFLICT (device_id)
    DO UPDATE SET
        branch_id = EXCLUDED.branch_id,
        hostname = COALESCE(EXCLUDED.hostname, lockguard_devices.hostname),
        ip_address = COALESCE(EXCLUDED.ip_address, lockguard_devices.ip_address),
        protection_state = EXCLUDED.protection_state,
        maintenance_mode = EXCLUDED.maintenance_mode,
        os_version = COALESCE(EXCLUDED.os_version, lockguard_devices.os_version),
        app_version = COALESCE(EXCLUDED.app_version, lockguard_devices.app_version),
        last_seen = now(),
        updated_at = now();

    -- Record heartbeat
    INSERT INTO public.lockguard_heartbeats (device_id, branch_id, hostname, ip_address, protection_state, maintenance_mode, os_version, app_version)
    VALUES (p_device_id, p_branch_id, p_hostname, p_ip_address, p_protection_state, p_maintenance_mode, p_os_version, p_app_version);

    RETURN jsonb_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.lockguard_heartbeat(TEXT, UUID, TEXT, TEXT, TEXT, BOOLEAN, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.lockguard_heartbeat(TEXT, UUID, TEXT, TEXT, TEXT, BOOLEAN, TEXT, TEXT) TO anon;
