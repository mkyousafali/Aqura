import { createClient } from '@supabase/supabase-js';
import { readFileSync } from 'fs';

const SUPABASE_URL = 'https://gqqmgqaelflqkdgpvbxl.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdxcW1ncWFlbGZscWtkZ3B2YnhsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzA0NDIzNzgsImV4cCI6MjA0NjAxODM3OH0.G0Q2_bZG3eo6KJ4E8G1g5PZ0iIHhXEo-A6vQQ9BQGnA';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function runAnalysis() {
  console.log('🔍 ANALYZING EXISTING TASKS IMPACT ON NEW RULES');
  console.log('=' .repeat(60));

  try {
    // Read the SQL file
    const sqlContent = readFileSync('./analyze-existing-tasks-impact.sql', 'utf8');
    
    // Split into individual queries (by semicolon followed by newlines)
    const queries = sqlContent
      .split(/;\s*\n\s*(?=--|\n|$)/)
      .filter(query => query.trim() && !query.trim().startsWith('--'));

    console.log(`📋 Found ${queries.length} analysis queries to run\\n`);

    for (let i = 0; i < queries.length; i++) {
      const query = queries[i].trim();
      if (!query) continue;

      console.log(`🔍 Running analysis query ${i + 1}...`);
      
      try {
        // Use RPC to execute raw SQL
        const { data, error } = await supabase.rpc('exec_sql', { 
          sql_query: query 
        });

        if (error) {
          console.error(`❌ Error in query ${i + 1}:`, error);
          continue;
        }

        if (data && data.length > 0) {
          console.log('✅ Results:');
          console.table(data);
        } else {
          console.log('✅ Query executed successfully (no results)');
        }
        
      } catch (queryError) {
        console.error(`💥 Exception in query ${i + 1}:`, queryError);
      }

      console.log('\\n' + '-'.repeat(50) + '\\n');
    }

    // Manual analysis for backward compatibility
    console.log('\\n🎯 BACKWARD COMPATIBILITY ANALYSIS');
    console.log('=' .repeat(50));

    // Check receiving_tasks structure manually
    const { data: tasks, error: tasksError } = await supabase
      .from('receiving_tasks')
      .select('id, role_type, task_completed, completed_at, completion_photo_url, receiving_record_id, created_at')
      .order('created_at', { ascending: false })
      .limit(100);

    if (tasksError) {
      console.error('❌ Error fetching tasks:', tasksError);
      return;
    }

    console.log(`\\n📊 Sample of ${tasks.length} recent tasks:`);
    
    // Analyze photo column presence
    const hasPhotoColumn = tasks.length > 0 && tasks[0].hasOwnProperty('completion_photo_url');
    console.log(`📷 completion_photo_url column exists: ${hasPhotoColumn ? 'YES' : 'NO'}`);

    // Count completed tasks by role
    const completedTasks = tasks.filter(t => t.task_completed);
    const tasksByRole = {};
    
    completedTasks.forEach(task => {
      if (!tasksByRole[task.role_type]) {
        tasksByRole[task.role_type] = { total: 0, withPhoto: 0, withoutPhoto: 0 };
      }
      tasksByRole[task.role_type].total++;
      
      if (hasPhotoColumn) {
        if (task.completion_photo_url) {
          tasksByRole[task.role_type].withPhoto++;
        } else {
          tasksByRole[task.role_type].withoutPhoto++;
        }
      }
    });

    console.log('\\n📋 Completed tasks by role (from sample):');
    Object.entries(tasksByRole).forEach(([role, stats]) => {
      console.log(`   ${role}: ${stats.total} total${hasPhotoColumn ? ` (${stats.withPhoto} with photo, ${stats.withoutPhoto} without photo)` : ''}`);
    });

    // Check for dependency violations
    const receivingRecords = {};
    tasks.forEach(task => {
      if (!receivingRecords[task.receiving_record_id]) {
        receivingRecords[task.receiving_record_id] = {
          roles: [],
          shelfStockerCompleted: false,
          shelfStockerHasPhoto: false,
          dependentRolesCompleted: false
        };
      }
      
      const record = receivingRecords[task.receiving_record_id];
      
      if (task.task_completed) {
        record.roles.push(task.role_type);
        
        if (task.role_type === 'shelf_stocker') {
          record.shelfStockerCompleted = true;
          record.shelfStockerHasPhoto = !!task.completion_photo_url;
        }
        
        if (['branch_manager', 'night_supervisor'].includes(task.role_type)) {
          record.dependentRolesCompleted = true;
        }
      }
    });

    const recordsWithViolations = Object.entries(receivingRecords).filter(([_, record]) => {
      return record.dependentRolesCompleted && 
             (!record.shelfStockerCompleted || !record.shelfStockerHasPhoto);
    });

    console.log(`\\n🚨 Potential rule violations in sample: ${recordsWithViolations.length}`);
    
    if (recordsWithViolations.length > 0) {
      console.log('   Records with dependent roles completed but shelf stocker issues:');
      recordsWithViolations.slice(0, 5).forEach(([recordId, record]) => {
        console.log(`   - Record ${recordId}: ${record.roles.join(', ')} | Shelf stocker: ${record.shelfStockerCompleted ? 'completed' : 'not completed'} | Photo: ${record.shelfStockerHasPhoto ? 'yes' : 'no'}`);
      });
    }

    console.log('\\n✅ FINAL RECOMMENDATIONS:');
    console.log('=' .repeat(50));
    console.log('\\n🎯 STRATEGY: GRANDFATHER APPROACH');
    console.log('   ✅ Existing completed tasks = LEGACY (no changes required)');
    console.log('   🆕 New tasks = FULL RULE ENFORCEMENT');
    console.log('   🔧 Implementation: Add rule_effective_date to track when rules became active');
    
    console.log('\\n📋 SPECIFIC HANDLING:');
    console.log('   🏗️  NEW tasks (created after rule deployment):');
    console.log('      - Shelf stocker: Photo upload MANDATORY');
    console.log('      - Branch manager/Night supervisor: BLOCKED until shelf stocker completes WITH photo');
    
    console.log('\\n   🗂️  EXISTING completed tasks:');
    console.log('      - NO CHANGES required (grandfathered)');
    console.log('      - Dependencies already satisfied');
    console.log('      - Photo requirements waived');
    
    console.log('\\n   ⏳ EXISTING incomplete tasks:');
    console.log('      - Check creation date vs rule effective date');
    console.log('      - Pre-rule tasks: Apply legacy logic');
    console.log('      - Post-rule tasks: Apply new rules');

    console.log('\\n🔧 TECHNICAL IMPLEMENTATION:');
    console.log('   1. Add migration timestamp as rule_effective_date');
    console.log('   2. Modify dependency checking function to check task.created_at');
    console.log('   3. Bypass photo/dependency rules for pre-migration tasks');
    console.log('   4. Full enforcement for post-migration tasks');
    
    console.log('\\n💡 USER IMPACT:');
    console.log('   📅 Zero impact on existing completed tasks');
    console.log('   🔄 Smooth transition for users');
    console.log('   📱 Clear messaging about new requirements');
    console.log('   ✨ Enhanced workflow for future operations');

  } catch (error) {
    console.error('💥 Analysis failed:', error);
  }
}

runAnalysis().catch(console.error);