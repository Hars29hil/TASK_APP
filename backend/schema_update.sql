-- 1. Add new columns to task_steps for tracking deadlines, durations, and start times
ALTER TABLE task_steps ADD COLUMN IF NOT EXISTS deadline TIMESTAMP WITH TIME ZONE;
ALTER TABLE task_steps ADD COLUMN IF NOT EXISTS duration_days INTEGER DEFAULT 2;
ALTER TABLE task_steps ADD COLUMN IF NOT EXISTS extension_days INTEGER DEFAULT 0;
ALTER TABLE task_steps ADD COLUMN IF NOT EXISTS started_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE task_steps ADD COLUMN IF NOT EXISTS started_by UUID REFERENCES profiles(id) ON DELETE SET NULL;
ALTER TABLE task_steps ADD COLUMN IF NOT EXISTS blocked_reason TEXT;

-- 2. Create the deadline_extensions table for requesting and tracking step deadline extensions
CREATE TABLE IF NOT EXISTS deadline_extensions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id UUID REFERENCES tasks(id) ON DELETE CASCADE,
    step_id UUID REFERENCES task_steps(id) ON DELETE CASCADE,
    requested_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    days_requested INTEGER NOT NULL,
    reason TEXT,
    status TEXT NOT NULL DEFAULT 'pending', -- 'pending', 'approved', 'rejected'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    resolved_at TIMESTAMP WITH TIME ZONE,
    resolved_by UUID REFERENCES profiles(id) ON DELETE SET NULL
);

-- 3. Add indexes on deadline_extensions for performance
CREATE INDEX IF NOT EXISTS idx_deadline_extensions_task ON deadline_extensions(task_id);
CREATE INDEX IF NOT EXISTS idx_deadline_extensions_step ON deadline_extensions(step_id);

-- 4. Drop and recreate check constraint on task_steps status column to allow new states
ALTER TABLE task_steps DROP CONSTRAINT IF EXISTS task_steps_status_check;
ALTER TABLE task_steps ADD CONSTRAINT task_steps_status_check CHECK (status IN ('pending', 'ready', 'in_progress', 'completed', 'blocked', 'extended', 'waiting_approval', 'active'));

