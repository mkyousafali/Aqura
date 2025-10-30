-- Basic RLS Policies Template
-- Generated on: 2025-10-30T21:55:45.337Z

-- Users can view their own records
CREATE POLICY "Users can view own records" ON public.users
    FOR SELECT TO authenticated
    USING (auth.uid() = id);

-- Users can update their own records
CREATE POLICY "Users can update own records" ON public.users
    FOR UPDATE TO authenticated
    USING (auth.uid() = id);

-- Employees can view their own HR records
CREATE POLICY "Employees can view own HR records" ON public.hr_employees
    FOR SELECT TO authenticated
    USING (
        user_id = auth.uid() OR
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() 
            AND employee_id = hr_employees.id
        )
    );

-- Task assignments visibility
CREATE POLICY "Users can view assigned tasks" ON public.task_assignments
    FOR SELECT TO authenticated
    USING (assigned_to = auth.uid());

-- Quick task assignments visibility
CREATE POLICY "Users can view assigned quick tasks" ON public.quick_task_assignments
    FOR SELECT TO authenticated
    USING (assigned_to = auth.uid());

-- Warning visibility
CREATE POLICY "Users can view their warnings" ON public.employee_warnings
    FOR SELECT TO authenticated
    USING (
        user_id = auth.uid() OR
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() 
            AND employee_id = employee_warnings.employee_id
        )
    );

-- Notification visibility
CREATE POLICY "Users can view their notifications" ON public.notifications
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM notification_recipients nr
            WHERE nr.notification_id = notifications.id
            AND nr.user_id = auth.uid()
        )
    );
