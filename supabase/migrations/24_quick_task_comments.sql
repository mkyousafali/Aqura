-- Create quick_task_comments table for managing comments on quick tasks
-- This table stores comments and notes related to quick tasks

-- Create the quick_task_comments table
CREATE TABLE IF NOT EXISTS public.quick_task_comments (
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    quick_task_id UUID NOT NULL,
    comment TEXT NOT NULL,
    comment_type CHARACTER VARYING(50) NULL DEFAULT 'comment'::character varying,
    created_by UUID NULL,
    created_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    
    CONSTRAINT quick_task_comments_pkey PRIMARY KEY (id),
    CONSTRAINT quick_task_comments_created_by_fkey 
        FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL,
    CONSTRAINT quick_task_comments_quick_task_id_fkey 
        FOREIGN KEY (quick_task_id) REFERENCES quick_tasks (id) ON DELETE CASCADE
) TABLESPACE pg_default;

-- Create indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_quick_task_comments_task 
ON public.quick_task_comments USING btree (quick_task_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_quick_task_comments_created_by 
ON public.quick_task_comments USING btree (created_by) 
TABLESPACE pg_default;

-- Create additional useful indexes
CREATE INDEX IF NOT EXISTS idx_quick_task_comments_comment_type 
ON public.quick_task_comments (comment_type);

CREATE INDEX IF NOT EXISTS idx_quick_task_comments_created_at 
ON public.quick_task_comments (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_quick_task_comments_task_created 
ON public.quick_task_comments (quick_task_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_quick_task_comments_user_created 
ON public.quick_task_comments (created_by, created_at DESC) 
WHERE created_by IS NOT NULL;

-- Create text search index for comments
CREATE INDEX IF NOT EXISTS idx_quick_task_comments_text_search 
ON public.quick_task_comments USING gin (to_tsvector('english', comment));

-- Add updated_at column and trigger
ALTER TABLE public.quick_task_comments 
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT now();

CREATE OR REPLACE FUNCTION update_quick_task_comments_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_quick_task_comments_updated_at 
BEFORE UPDATE ON quick_task_comments 
FOR EACH ROW 
EXECUTE FUNCTION update_quick_task_comments_updated_at();

-- Add data validation constraints
ALTER TABLE public.quick_task_comments 
ADD CONSTRAINT chk_comment_not_empty 
CHECK (TRIM(comment) != '');

ALTER TABLE public.quick_task_comments 
ADD CONSTRAINT chk_comment_type_valid 
CHECK (comment_type IN (
    'comment', 'note', 'update', 'status_change', 'system', 'attachment', 'review'
));

-- Add additional columns for enhanced functionality
ALTER TABLE public.quick_task_comments 
ADD COLUMN IF NOT EXISTS is_edited BOOLEAN DEFAULT false;

ALTER TABLE public.quick_task_comments 
ADD COLUMN IF NOT EXISTS edited_at TIMESTAMP WITH TIME ZONE;

ALTER TABLE public.quick_task_comments 
ADD COLUMN IF NOT EXISTS parent_comment_id UUID;

ALTER TABLE public.quick_task_comments 
ADD COLUMN IF NOT EXISTS is_private BOOLEAN DEFAULT false;

ALTER TABLE public.quick_task_comments 
ADD COLUMN IF NOT EXISTS attachments JSONB;

-- Add foreign key for parent comment (for replies)
ALTER TABLE public.quick_task_comments 
ADD CONSTRAINT quick_task_comments_parent_comment_id_fkey 
FOREIGN KEY (parent_comment_id) REFERENCES quick_task_comments (id) ON DELETE CASCADE;

-- Create index for parent comments
CREATE INDEX IF NOT EXISTS idx_quick_task_comments_parent 
ON public.quick_task_comments (parent_comment_id) 
WHERE parent_comment_id IS NOT NULL;

-- Add table and column comments
COMMENT ON TABLE public.quick_task_comments IS 'Comments and notes for quick tasks with threading support';
COMMENT ON COLUMN public.quick_task_comments.id IS 'Unique identifier for the comment';
COMMENT ON COLUMN public.quick_task_comments.quick_task_id IS 'Reference to the quick task';
COMMENT ON COLUMN public.quick_task_comments.comment IS 'The comment text content';
COMMENT ON COLUMN public.quick_task_comments.comment_type IS 'Type of comment (comment, note, update, etc.)';
COMMENT ON COLUMN public.quick_task_comments.created_by IS 'User who created the comment';
COMMENT ON COLUMN public.quick_task_comments.created_at IS 'When the comment was created';
COMMENT ON COLUMN public.quick_task_comments.updated_at IS 'When the comment was last updated';
COMMENT ON COLUMN public.quick_task_comments.is_edited IS 'Whether the comment has been edited';
COMMENT ON COLUMN public.quick_task_comments.edited_at IS 'When the comment was last edited';
COMMENT ON COLUMN public.quick_task_comments.parent_comment_id IS 'Parent comment for replies (threading)';
COMMENT ON COLUMN public.quick_task_comments.is_private IS 'Whether the comment is private (visible to limited users)';
COMMENT ON COLUMN public.quick_task_comments.attachments IS 'JSON array of attachment information';

-- Create view for comments with user details
CREATE OR REPLACE VIEW quick_task_comments_with_details AS
SELECT 
    qtc.id,
    qtc.quick_task_id,
    qt.title as task_title,
    qtc.comment,
    qtc.comment_type,
    qtc.created_by,
    u.username,
    u.full_name as created_by_name,
    qtc.parent_comment_id,
    qtc.is_private,
    qtc.is_edited,
    qtc.edited_at,
    qtc.attachments,
    qtc.created_at,
    qtc.updated_at,
    CASE 
        WHEN qtc.parent_comment_id IS NULL THEN 0
        ELSE 1
    END as comment_level
FROM quick_task_comments qtc
LEFT JOIN users u ON qtc.created_by = u.id
LEFT JOIN quick_tasks qt ON qtc.quick_task_id = qt.id
ORDER BY qtc.quick_task_id, qtc.created_at ASC;

-- Create function to get task comments with threading
CREATE OR REPLACE FUNCTION get_task_comments_threaded(task_id UUID, include_private BOOLEAN DEFAULT false)
RETURNS TABLE(
    comment_id UUID,
    comment_text TEXT,
    comment_type VARCHAR,
    created_by UUID,
    created_by_name VARCHAR,
    parent_comment_id UUID,
    is_private BOOLEAN,
    is_edited BOOLEAN,
    edited_at TIMESTAMPTZ,
    attachments JSONB,
    created_at TIMESTAMPTZ,
    comment_level INTEGER,
    reply_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    WITH RECURSIVE comment_tree AS (
        -- Root comments (no parent)
        SELECT 
            qtc.id,
            qtc.comment,
            qtc.comment_type,
            qtc.created_by,
            COALESCE(u.full_name, u.username) as created_by_name,
            qtc.parent_comment_id,
            qtc.is_private,
            qtc.is_edited,
            qtc.edited_at,
            qtc.attachments,
            qtc.created_at,
            0 as comment_level,
            qtc.created_at as sort_order
        FROM quick_task_comments qtc
        LEFT JOIN users u ON qtc.created_by = u.id
        WHERE qtc.quick_task_id = task_id 
          AND qtc.parent_comment_id IS NULL
          AND (include_private = true OR qtc.is_private = false)
        
        UNION ALL
        
        -- Replies (with parent)
        SELECT 
            qtc.id,
            qtc.comment,
            qtc.comment_type,
            qtc.created_by,
            COALESCE(u.full_name, u.username) as created_by_name,
            qtc.parent_comment_id,
            qtc.is_private,
            qtc.is_edited,
            qtc.edited_at,
            qtc.attachments,
            qtc.created_at,
            ct.comment_level + 1,
            ct.sort_order
        FROM quick_task_comments qtc
        LEFT JOIN users u ON qtc.created_by = u.id
        INNER JOIN comment_tree ct ON qtc.parent_comment_id = ct.id
        WHERE qtc.quick_task_id = task_id
          AND (include_private = true OR qtc.is_private = false)
    )
    SELECT 
        ct.id,
        ct.comment,
        ct.comment_type,
        ct.created_by,
        ct.created_by_name,
        ct.parent_comment_id,
        ct.is_private,
        ct.is_edited,
        ct.edited_at,
        ct.attachments,
        ct.created_at,
        ct.comment_level,
        (SELECT COUNT(*) FROM quick_task_comments WHERE parent_comment_id = ct.id) as reply_count
    FROM comment_tree ct
    ORDER BY ct.sort_order, ct.comment_level, ct.created_at;
END;
$$ LANGUAGE plpgsql;

-- Create function to add a comment
CREATE OR REPLACE FUNCTION add_task_comment(
    task_id UUID,
    comment_text TEXT,
    comment_type_param VARCHAR DEFAULT 'comment',
    created_by_param UUID DEFAULT NULL,
    parent_id UUID DEFAULT NULL,
    is_private_param BOOLEAN DEFAULT false,
    attachments_param JSONB DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    comment_id UUID;
BEGIN
    INSERT INTO quick_task_comments (
        quick_task_id,
        comment,
        comment_type,
        created_by,
        parent_comment_id,
        is_private,
        attachments
    ) VALUES (
        task_id,
        comment_text,
        comment_type_param,
        created_by_param,
        parent_id,
        is_private_param,
        attachments_param
    ) RETURNING id INTO comment_id;
    
    RETURN comment_id;
END;
$$ LANGUAGE plpgsql;

-- Create function to edit a comment
CREATE OR REPLACE FUNCTION edit_task_comment(
    comment_id UUID,
    new_comment_text TEXT,
    editor_user_id UUID
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE quick_task_comments 
    SET comment = new_comment_text,
        is_edited = true,
        edited_at = now(),
        updated_at = now()
    WHERE id = comment_id 
      AND (created_by = editor_user_id OR editor_user_id IN (
          SELECT id FROM users WHERE role IN ('admin', 'manager')
      ));
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Create function to get comment statistics
CREATE OR REPLACE FUNCTION get_task_comment_stats(task_id UUID)
RETURNS TABLE(
    total_comments BIGINT,
    comment_count BIGINT,
    note_count BIGINT,
    update_count BIGINT,
    system_count BIGINT,
    private_count BIGINT,
    reply_count BIGINT,
    unique_commenters BIGINT,
    latest_comment_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) as total_comments,
        COUNT(*) FILTER (WHERE comment_type = 'comment') as comment_count,
        COUNT(*) FILTER (WHERE comment_type = 'note') as note_count,
        COUNT(*) FILTER (WHERE comment_type = 'update') as update_count,
        COUNT(*) FILTER (WHERE comment_type = 'system') as system_count,
        COUNT(*) FILTER (WHERE is_private = true) as private_count,
        COUNT(*) FILTER (WHERE parent_comment_id IS NOT NULL) as reply_count,
        COUNT(DISTINCT created_by) as unique_commenters,
        MAX(created_at) as latest_comment_at
    FROM quick_task_comments
    WHERE quick_task_id = task_id;
END;
$$ LANGUAGE plpgsql;

-- Create function to delete a comment (soft delete by setting content)
CREATE OR REPLACE FUNCTION delete_task_comment(
    comment_id UUID,
    deleter_user_id UUID
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE quick_task_comments 
    SET comment = '[Comment deleted]',
        comment_type = 'system',
        is_edited = true,
        edited_at = now(),
        updated_at = now()
    WHERE id = comment_id 
      AND (created_by = deleter_user_id OR deleter_user_id IN (
          SELECT id FROM users WHERE role IN ('admin', 'manager')
      ));
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to update task's last activity when comment is added
CREATE OR REPLACE FUNCTION update_task_last_activity_on_comment()
RETURNS TRIGGER AS $$
BEGIN
    -- Update the quick_tasks table with last activity if that column exists
    BEGIN
        UPDATE quick_tasks 
        SET updated_at = now()
        WHERE id = NEW.quick_task_id;
    EXCEPTION
        WHEN undefined_column THEN
            -- Column doesn't exist, ignore
            NULL;
    END;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_task_last_activity_on_comment
AFTER INSERT ON quick_task_comments 
FOR EACH ROW 
EXECUTE FUNCTION update_task_last_activity_on_comment();

RAISE NOTICE 'quick_task_comments table created with threading and comprehensive comment management features';