// =====================================================
// ANALYZE EXISTING TASKS IMPACT
// =====================================================
// This script checks how our new photo and dependency rules
// will affect existing completed tasks
// =====================================================

import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://gqqmgqaelflqkdgpvbxl.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdxcW1ncWFlbGZscWtkZ3B2YnhsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzA0NDIzNzgsImV4cCI6MjA0NjAxODM3OH0.G0Q2_bZG3eo6KJ4E8G1g5PZ0iIHhXEo-A6vQQ9BQGnA';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function analyzeExistingTasksImpact() {
  console.log('🔍 ANALYZING IMPACT ON EXISTING TASKS');
  console.log('=' .repeat(60));

  try {
    // 1. Check current receiving_tasks table structure
    console.log('\\n1️⃣ Checking current receiving_tasks table structure...');
    const { data: sampleTask, error: sampleError } = await supabase
      .from('receiving_tasks')
      .select('*')
      .limit(1)
      .single();

    if (sampleError) {
      console.error('❌ Error accessing receiving_tasks:', sampleError);
      return;
    }

    const currentColumns = Object.keys(sampleTask);
    const hasPhotoColumn = currentColumns.includes('completion_photo_url');
    
    console.log('✅ Current columns:', currentColumns.join(', '));
    console.log(`📷 Has completion_photo_url column: ${hasPhotoColumn ? 'YES' : 'NO'}`);

    // 2. Check existing completed tasks
    console.log('\\n2️⃣ Checking existing completed tasks...');
    const { data: completedTasks, error: completedError } = await supabase
      .from('receiving_tasks')
      .select('id, role_type, task_completed, completed_at, completion_photo_url, receiving_record_id')
      .eq('task_completed', true)
      .order('completed_at', { ascending: false });

    if (completedError) {
      console.error('❌ Error fetching completed tasks:', completedError);
      return;
    }

    console.log(`✅ Found ${completedTasks.length} completed tasks`);

    // Group by role type
    const tasksByRole = {};
    completedTasks.forEach(task => {
      if (!tasksByRole[task.role_type]) {
        tasksByRole[task.role_type] = [];
      }
      tasksByRole[task.role_type].push(task);
    });

    console.log('\\n📊 Completed tasks by role:');
    Object.entries(tasksByRole).forEach(([role, tasks]) => {
      const withPhoto = tasks.filter(t => t.completion_photo_url).length;
      const withoutPhoto = tasks.length - withPhoto;
      
      console.log(`   ${role}: ${tasks.length} total (${withPhoto} with photo, ${withoutPhoto} without photo)`);
    });

    // 3. Check shelf stocker tasks specifically
    console.log('\\n3️⃣ Analyzing shelf stocker tasks impact...');
    const shelfStockerTasks = tasksByRole['shelf_stocker'] || [];
    
    if (shelfStockerTasks.length === 0) {
      console.log('⚠️  No completed shelf stocker tasks found');
    } else {
      console.log(`📋 Found ${shelfStockerTasks.length} completed shelf stocker tasks:`);
      
      const withPhoto = shelfStockerTasks.filter(t => t.completion_photo_url).length;
      const withoutPhoto = shelfStockerTasks.length - withPhoto;
      
      console.log(`   ✅ With photos: ${withPhoto}`);
      console.log(`   ❌ Without photos: ${withoutPhoto}`);
      
      if (withoutPhoto > 0) {
        console.log('\\n🚨 IMPACT ANALYSIS:');
        console.log(`   ${withoutPhoto} shelf stocker task(s) completed WITHOUT photos`);
        console.log('   These will be considered "legacy completed tasks"');
      }
    }

    // 4. Check branch manager and night supervisor tasks
    console.log('\\n4️⃣ Checking dependent role tasks...');
    const branchManagerTasks = tasksByRole['branch_manager'] || [];
    const nightSupervisorTasks = tasksByRole['night_supervisor'] || [];
    
    console.log(`📋 Branch manager completed tasks: ${branchManagerTasks.length}`);
    console.log(`📋 Night supervisor completed tasks: ${nightSupervisorTasks.length}`);

    // 5. Test dependency logic on existing data
    console.log('\\n5️⃣ Testing dependency logic on existing receiving records...');
    
    // Get unique receiving record IDs from completed tasks
    const receivingRecordIds = [...new Set(completedTasks.map(t => t.receiving_record_id))];
    console.log(`🗃️  Found ${receivingRecordIds.length} unique receiving records with completed tasks`);

    // Check each receiving record for task completion patterns
    for (let i = 0; i < Math.min(receivingRecordIds.length, 5); i++) { // Check first 5
      const recordId = receivingRecordIds[i];
      const recordTasks = completedTasks.filter(t => t.receiving_record_id === recordId);
      
      console.log(`\\n   📋 Receiving Record ${i + 1} (${recordId}):`);
      console.log(`      Total completed tasks: ${recordTasks.length}`);
      
      const roles = recordTasks.map(t => t.role_type);
      const hasShelfStocker = roles.includes('shelf_stocker');
      const hasBranchManager = roles.includes('branch_manager');
      const hasNightSupervisor = roles.includes('night_supervisor');
      
      console.log(`      Roles completed: ${roles.join(', ')}`);
      console.log(`      Shelf stocker completed: ${hasShelfStocker ? 'YES' : 'NO'}`);
      console.log(`      Branch manager completed: ${hasBranchManager ? 'YES' : 'NO'}`);
      console.log(`      Night supervisor completed: ${hasNightSupervisor ? 'YES' : 'NO'}`);
      
      // Check if this would violate our new dependency rules
      if ((hasBranchManager || hasNightSupervisor) && !hasShelfStocker) {
        console.log(`      🚨 RULE VIOLATION: Dependent roles completed without shelf stocker!`);
      } else if (hasShelfStocker) {
        const shelfStockerTask = recordTasks.find(t => t.role_type === 'shelf_stocker');
        const hasPhoto = !!shelfStockerTask.completion_photo_url;
        console.log(`      📷 Shelf stocker photo: ${hasPhoto ? 'YES' : 'NO'}`);
        
        if (!hasPhoto && (hasBranchManager || hasNightSupervisor)) {
          console.log(`      ⚠️  LEGACY ISSUE: Dependent roles completed but shelf stocker has no photo`);
        }
      }
    }

    // 6. Provide recommendations
    console.log('\\n6️⃣ RECOMMENDATIONS FOR IMPLEMENTATION:');
    console.log('=' .repeat(50));
    
    console.log('\\n🎯 STRATEGY: Grandfather Existing Completed Tasks');
    console.log('   ✅ Tasks already completed = Legacy exceptions');
    console.log('   🆕 New tasks = Must follow new rules');
    console.log('   🔧 Implementation approach:');
    console.log('      1. Add "legacy_completion" flag to existing completed tasks');
    console.log('      2. Dependency checking only applies to tasks created AFTER rule implementation');
    console.log('      3. Photo requirements only apply to NEW shelf stocker tasks');
    
    console.log('\\n📋 SPECIFIC HANDLING:');
    console.log('   🏗️  For NEW tasks (created after migration):');
    console.log('      - Shelf stocker: Photo mandatory');
    console.log('      - Branch manager: Blocked until shelf stocker completes WITH photo');
    console.log('      - Night supervisor: Blocked until shelf stocker completes WITH photo');
    
    console.log('\\n   🗂️  For EXISTING completed tasks:');
    console.log('      - No changes required');
    console.log('      - Dependencies already satisfied (grandfathered)');
    console.log('      - Photo requirements waived (legacy exception)');
    
    console.log('\\n   ⏳ For EXISTING incomplete tasks:');
    console.log('      - Apply new rules only if shelf stocker task is still pending');
    console.log('      - If shelf stocker already completed without photo: Allow dependent tasks');
    console.log('      - If shelf stocker still pending: Enforce photo requirement');

    console.log('\\n🔧 TECHNICAL IMPLEMENTATION:');
    console.log('   1. Add migration timestamp to track "rule effective date"');
    console.log('   2. Check task.created_at vs rule_effective_date in dependency function');
    console.log('   3. Bypass photo/dependency checks for pre-migration tasks');
    console.log('   4. Full enforcement for post-migration tasks');

    console.log('\\n✅ CONCLUSION:');
    console.log('   📅 Existing completed tasks: NO IMPACT (grandfathered)');
    console.log('   🆕 New tasks: Full rule enforcement');
    console.log('   🔄 Mixed scenarios: Smart handling based on creation date');
    console.log('   👥 User experience: Smooth transition with clear messaging');

  } catch (error) {
    console.error('💥 Unexpected error:', error);
  }
}

// Run the analysis
analyzeExistingTasksImpact().catch(console.error);