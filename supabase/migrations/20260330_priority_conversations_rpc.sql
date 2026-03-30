-- ============================================================
-- New RPC: get_wa_priority_conversations
-- Returns SOS and needs_human conversations separately
-- ============================================================

CREATE OR REPLACE FUNCTION get_wa_priority_conversations(
    p_account_id UUID
)
RETURNS TABLE (
    id UUID,
    customer_phone VARCHAR,
    customer_name TEXT,
    last_message_at TIMESTAMPTZ,
    last_message_preview TEXT,
    unread_count INT,
    is_bot_handling BOOLEAN,
    bot_type VARCHAR,
    handled_by VARCHAR,
    needs_human BOOLEAN,
    status VARCHAR,
    is_inside_24hr BOOLEAN,
    is_sos BOOLEAN,
    total_count BIGINT
) LANGUAGE plpgsql STABLE AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.id,
        c.customer_phone,
        c.customer_name,
        c.last_message_at,
        c.last_message_preview,
        c.unread_count,
        c.is_bot_handling,
        c.bot_type,
        c.handled_by,
        c.needs_human,
        c.status,
        CASE
            WHEN c.last_message_at IS NOT NULL
                 AND c.last_message_at > (NOW() - INTERVAL '24 hours')
            THEN TRUE
            ELSE FALSE
        END AS is_inside_24hr,
        c.is_sos,
        COUNT(*) OVER() AS total_count
    FROM wa_conversations c
    WHERE c.wa_account_id = p_account_id
      AND c.status = 'active'
      AND (c.is_sos = TRUE OR c.needs_human = TRUE)
    ORDER BY
        CASE WHEN c.is_sos = TRUE THEN 0 ELSE 1 END ASC,
        c.last_message_at DESC NULLS LAST;
END;
$$;

GRANT EXECUTE ON FUNCTION get_wa_priority_conversations(UUID) TO anon, authenticated, service_role;

-- ============================================================
-- Update: get_wa_conversations_fast
-- Exclude SOS and needs_human conversations from main list
-- ============================================================

DROP FUNCTION IF EXISTS get_wa_conversations_fast(UUID, INT, INT, TEXT, TEXT);

CREATE OR REPLACE FUNCTION get_wa_conversations_fast(
    p_account_id UUID,
    p_limit INT DEFAULT 50,
    p_offset INT DEFAULT 0,
    p_search TEXT DEFAULT NULL,
    p_filter TEXT DEFAULT 'all'
)
RETURNS TABLE (
    id UUID,
    customer_phone VARCHAR,
    customer_name TEXT,
    last_message_at TIMESTAMPTZ,
    last_message_preview TEXT,
    unread_count INT,
    is_bot_handling BOOLEAN,
    bot_type VARCHAR,
    handled_by VARCHAR,
    needs_human BOOLEAN,
    status VARCHAR,
    is_inside_24hr BOOLEAN,
    is_sos BOOLEAN,
    total_count BIGINT
) LANGUAGE plpgsql STABLE AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.id,
        c.customer_phone,
        c.customer_name,
        c.last_message_at,
        c.last_message_preview,
        c.unread_count,
        c.is_bot_handling,
        c.bot_type,
        c.handled_by,
        c.needs_human,
        c.status,
        CASE
            WHEN c.last_message_at IS NOT NULL
                 AND c.last_message_at > (NOW() - INTERVAL '24 hours')
            THEN TRUE
            ELSE FALSE
        END AS is_inside_24hr,
        c.is_sos,
        COUNT(*) OVER() AS total_count
    FROM wa_conversations c
    WHERE c.wa_account_id = p_account_id
      AND c.status = 'active'
      -- Exclude priority conversations (SOS / needs_human) — they go in their own section
      AND c.is_sos IS NOT TRUE
      AND c.needs_human IS NOT TRUE
      -- Search filter
      AND (
          p_search IS NULL
          OR p_search = ''
          OR c.customer_name ILIKE '%' || p_search || '%'
          OR c.customer_phone ILIKE '%' || p_search || '%'
      )
      -- Chat filter
      AND (
          p_filter = 'all'
          OR (p_filter = 'unread' AND c.unread_count > 0)
          OR (p_filter = 'ai' AND c.is_bot_handling = TRUE AND c.bot_type = 'ai')
          OR (p_filter = 'bot' AND c.is_bot_handling = TRUE AND c.bot_type = 'auto_reply')
          OR (p_filter = 'human' AND c.is_bot_handling = FALSE)
      )
    ORDER BY c.last_message_at DESC NULLS LAST
    LIMIT p_limit
    OFFSET p_offset;
END;
$$;

GRANT EXECUTE ON FUNCTION get_wa_conversations_fast(UUID, INT, INT, TEXT, TEXT) TO anon, authenticated, service_role;
