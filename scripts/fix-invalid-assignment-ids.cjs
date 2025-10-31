const { createClient } = require('@supabase/supabase-js');

// Supabase configuration
const SUPABASE_URL = 'https://vmypotfsyrvuublyddyt.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTY0ODI0ODksImV4cCI6MjA3MjA1ODQ4OX0.-HBW0CJM4sO35WjCf0flxuvLLEeQ_eeUnWmLQMlkWQs';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function fixInvalidAssignmentIds() {
    console.log('🔍 Checking for invalid assignment IDs in task_assignments...\n');

    try {
        // Get all task assignments
        const { data: assignments, error } = await supabase
            .from('task_assignments')
            .select('id, task_id, assigned_to_user_id, assigned_by, status')
            .order('assigned_at', { ascending: false });

        if (error) {
            console.error('❌ Error fetching assignments:', error);
            return;
        }

        console.log(`📊 Total assignments found: ${assignments.length}\n`);

        // UUID regex pattern
        const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

        let invalidCount = 0;
        const invalidAssignments = [];

        // Check each assignment
        assignments.forEach((assignment, index) => {
            const isValidId = uuidRegex.test(assignment.id);
            const isValidTaskId = uuidRegex.test(assignment.task_id);
            const isValidUserId = uuidRegex.test(assignment.assigned_to_user_id);
            const isValidAssignedBy = uuidRegex.test(assignment.assigned_by);

            if (!isValidId || !isValidTaskId || !isValidUserId || !isValidAssignedBy) {
                invalidCount++;
                invalidAssignments.push({
                    index: index + 1,
                    id: assignment.id,
                    isValidId,
                    task_id: assignment.task_id,
                    isValidTaskId,
                    assigned_to_user_id: assignment.assigned_to_user_id,
                    isValidUserId,
                    assigned_by: assignment.assigned_by,
                    isValidAssignedBy,
                    status: assignment.status
                });
            }
        });

        if (invalidCount > 0) {
            console.log(`⚠️  Found ${invalidCount} assignment(s) with invalid UUID fields:\n`);
            invalidAssignments.forEach(inv => {
                console.log(`Assignment #${inv.index}:`);
                console.log(`  ID: ${inv.id} ${!inv.isValidId ? '❌ INVALID' : '✅'}`);
                console.log(`  Task ID: ${inv.task_id} ${!inv.isValidTaskId ? '❌ INVALID' : '✅'}`);
                console.log(`  User ID: ${inv.assigned_to_user_id} ${!inv.isValidUserId ? '❌ INVALID' : '✅'}`);
                console.log(`  Assigned By: ${inv.assigned_by} ${!inv.isValidAssignedBy ? '❌ INVALID' : '✅'}`);
                console.log(`  Status: ${inv.status}`);
                console.log('');
            });
        } else {
            console.log('✅ All assignments have valid UUID fields!\n');
        }

        // Check task_completions for invalid assignment_id references
        console.log('🔍 Checking task_completions for invalid assignment_id references...\n');

        const { data: completions, error: completionsError } = await supabase
            .from('task_completions')
            .select('id, task_id, assignment_id, completed_by, completed_at')
            .order('completed_at', { ascending: false });

        if (completionsError) {
            console.error('❌ Error fetching completions:', completionsError);
            return;
        }

        console.log(`📊 Total completions found: ${completions?.length || 0}\n`);

        let invalidCompletionCount = 0;
        const invalidCompletions = [];

        if (completions && completions.length > 0) {
            completions.forEach((completion, index) => {
                const isValidId = uuidRegex.test(completion.id);
                const isValidTaskId = uuidRegex.test(completion.task_id);
                const isValidAssignmentId = uuidRegex.test(completion.assignment_id);
                const isValidCompletedBy = uuidRegex.test(completion.completed_by);

                if (!isValidId || !isValidTaskId || !isValidAssignmentId || !isValidCompletedBy) {
                    invalidCompletionCount++;
                    invalidCompletions.push({
                        index: index + 1,
                        id: completion.id,
                        isValidId,
                        task_id: completion.task_id,
                        isValidTaskId,
                        assignment_id: completion.assignment_id,
                        isValidAssignmentId,
                        completed_by: completion.completed_by,
                        isValidCompletedBy,
                        completed_at: completion.completed_at
                    });
                }
            });

            if (invalidCompletionCount > 0) {
                console.log(`⚠️  Found ${invalidCompletionCount} completion(s) with invalid UUID fields:\n`);
                invalidCompletions.forEach(inv => {
                    console.log(`Completion #${inv.index}:`);
                    console.log(`  ID: ${inv.id} ${!inv.isValidId ? '❌ INVALID' : '✅'}`);
                    console.log(`  Task ID: ${inv.task_id} ${!inv.isValidTaskId ? '❌ INVALID' : '✅'}`);
                    console.log(`  Assignment ID: ${inv.assignment_id} ${!inv.isValidAssignmentId ? '❌ INVALID' : '✅'}`);
                    console.log(`  Completed By: ${inv.completed_by} ${!inv.isValidCompletedBy ? '❌ INVALID' : '✅'}`);
                    console.log(`  Completed At: ${inv.completed_at}`);
                    console.log('');
                });
            } else {
                console.log('✅ All completions have valid UUID fields!\n');
            }
        }

        // Summary
        console.log('\n' + '='.repeat(50));
        console.log('📋 SUMMARY');
        console.log('='.repeat(50));
        console.log(`Total Assignments: ${assignments.length}`);
        console.log(`Invalid Assignments: ${invalidCount}`);
        console.log(`Total Completions: ${completions?.length || 0}`);
        console.log(`Invalid Completions: ${invalidCompletionCount}`);
        console.log('='.repeat(50) + '\n');

        if (invalidCount > 0 || invalidCompletionCount > 0) {
            console.log('⚠️  ACTION REQUIRED:');
            console.log('These records have invalid UUID fields and need to be corrected in the database.');
            console.log('This is likely causing the "invalid input syntax for type uuid" error.\n');
        }

    } catch (error) {
        console.error('❌ Error:', error);
    }
}

fixInvalidAssignmentIds();
