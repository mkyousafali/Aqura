-- =============================================================
-- RPC: get_wa_conversations_fast
-- Returns active conversations with 24hr window pre-calculated
-- Much faster than SELECT * from frontend (single indexed query)
-- =============================================================

-- Compound index for the exact query pattern
CREATE INDEX IF NOT EXISTS idx_wa_conv_account_status_lastmsg
ON wa_conversations (wa_account_id, status, last_message_at DESC);

-- Compound index for messages by conversation + created_at
CREATE INDEX IF NOT EXISTS idx_wa_messages_conv_created
ON wa_messages (conversation_id, created_at DESC);

CREATE OR REPLACE FUNCTION get_wa_conversations_fast(
    p_account_id UUID,
    p_limit INT DEFAULT 50,
    p_offset INT DEFAULT 0,
    p_search TEXT DEFAULT NULL,
    p_filter TEXT DEFAULT 'all'  -- all, unread, ai, bot, human
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
        -- Pre-calculate 24hr window
        CASE
            WHEN c.last_message_at IS NOT NULL
                 AND c.last_message_at > (NOW() - INTERVAL '24 hours')
            THEN TRUE
            ELSE FALSE
        END AS is_inside_24hr,
        -- Total count for pagination (using window function)
        COUNT(*) OVER() AS total_count
    FROM wa_conversations c
    WHERE c.wa_account_id = p_account_id
      AND c.status = 'active'
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

-- Grant access
GRANT EXECUTE ON FUNCTION get_wa_conversations_fast TO anon, authenticated, service_role;
