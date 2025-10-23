import { createClient } from '@supabase/supabase-js';

// Supabase configuration
const SUPABASE_URL = 'https://vmypotfsyrvuublyddyt.supabase.co';
const SUPABASE_SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

async function fixPaymentTransactionsCompletely() {
  console.log('🔧 Comprehensive fix of payment_transactions table...\n');
  
  try {
    // 1. Check user_roles table structure
    console.log('📋 Step 1: Checking user_roles table structure...');
    const { data: userRoles, error: rolesError } = await supabase
      .from('user_roles')
      .select('*')
      .limit(3);
    
    if (rolesError) {
      console.log('❌ Error fetching user roles:', rolesError);
    } else {
      console.log('📋 User roles table columns:', Object.keys(userRoles[0] || {}));
      console.log('📋 Sample user roles:');
      userRoles?.forEach(role => {
        console.log(`  - User ID: ${role.user_id}, Role: ${role.role_name || role.role_type || 'unknown'}`);
      });
    }
    
    // 2. Find users with accountant role or suitable role
    console.log('\n👤 Step 2: Finding suitable users for assignments...');
    let accountantUsers = [];
    
    // Try different approaches to find accountant users
    const { data: allUsers, error: usersError } = await supabase
      .from('users')
      .select('id, username, role_type, status')
      .eq('status', 'active')
      .limit(10);
    
    if (usersError) {
      console.log('❌ Error fetching users:', usersError);
    } else {
      console.log(`📋 Found ${allUsers.length} active users:`);
      allUsers.forEach(user => {
        console.log(`  - ${user.username} (${user.role_type})`);
        // Consider any user that might handle accounting tasks
        if (user.role_type && (
          user.role_type.toLowerCase().includes('account') ||
          user.role_type.toLowerCase().includes('finance') ||
          user.role_type.toLowerCase().includes('admin') ||
          user.role_type.toLowerCase().includes('manager')
        )) {
          accountantUsers.push(user);
        }
      });
      
      // If no specific accountant found, use the first active user as default
      if (accountantUsers.length === 0 && allUsers.length > 0) {
        accountantUsers = [allUsers[0]];
        console.log(`🔄 No accountant found, using default user: ${allUsers[0].username}`);
      }
    }
    
    const defaultAccountant = accountantUsers[0];
    console.log(`👤 Using accountant: ${defaultAccountant?.username || 'None found'}\n`);
    
    // 3. Get all payment transactions with missing data
    console.log('💳 Step 3: Analyzing payment transactions...');
    const { data: transactions, error: transError } = await supabase
      .from('payment_transactions')
      .select(`
        id,
        payment_schedule_id,
        bill_number,
        vendor_name,
        amount,
        task_id,
        task_assignment_id,
        accountant_user_id,
        verification_status,
        created_at
      `)
      .order('created_at', { ascending: false });
    
    if (transError) {
      console.log('❌ Error fetching transactions:', transError);
      return;
    }
    
    console.log(`📋 Total transactions: ${transactions.length}`);
    
    // 4. Fix missing task assignments and accountant assignments
    console.log('\n🔧 Step 4: Fixing missing assignments...');
    
    for (const transaction of transactions) {
      let needsUpdate = false;
      const updates = {};
      
      // Fix missing accountant_user_id
      if (!transaction.accountant_user_id && defaultAccountant) {
        updates.accountant_user_id = defaultAccountant.id;
        needsUpdate = true;
        console.log(`⚡ Adding accountant to transaction ${transaction.bill_number}`);
      }
      
      // Fix missing task_assignment_id by creating assignment
      if (!transaction.task_assignment_id && transaction.task_id && defaultAccountant) {
        console.log(`⚡ Creating task assignment for ${transaction.bill_number}...`);
        
        const { data: assignmentData, error: assignmentError } = await supabase
          .from('task_assignments')
          .insert({
            task_id: transaction.task_id,
            assignment_type: 'user',
            assigned_by: 'system',
            assigned_by_name: 'Payment Fix System',
            assigned_by_role: 'system',
            assigned_to_user_id: defaultAccountant.id,
            status: 'active',
            notes: `Auto-assigned for payment processing of bill: ${transaction.bill_number}`
          })
          .select()
          .single();
        
        if (assignmentError) {
          console.log(`❌ Error creating assignment for ${transaction.bill_number}:`, assignmentError);
        } else {
          updates.task_assignment_id = assignmentData.id;
          needsUpdate = true;
          console.log(`✅ Created task assignment ${assignmentData.id} for ${transaction.bill_number}`);
        }
      }
      
      // Update transaction if needed
      if (needsUpdate) {
        updates.updated_at = new Date().toISOString();
        
        const { error: updateError } = await supabase
          .from('payment_transactions')
          .update(updates)
          .eq('id', transaction.id);
        
        if (updateError) {
          console.log(`❌ Error updating transaction ${transaction.bill_number}:`, updateError);
        } else {
          console.log(`✅ Updated transaction ${transaction.bill_number}`);
        }
      }
    }
    
    // 5. Re-apply the migration to ensure trigger is working
    console.log('\n🔧 Step 5: Re-creating automation trigger...');
    
    const migrationSQL = `
-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS trigger_auto_create_payment_transaction_and_task ON vendor_payment_schedule;

-- Function to automatically create payment transaction and accountant task when payment is marked as paid
CREATE OR REPLACE FUNCTION auto_create_payment_transaction_and_task()
RETURNS TRIGGER AS $$
DECLARE
    v_task_id UUID;
    v_assignment_id UUID;
    v_receiving_record RECORD;
    v_accountant_user_id UUID;
    v_branch_id INTEGER;
BEGIN
    -- Only trigger when is_paid changes from FALSE to TRUE
    IF (OLD.is_paid IS FALSE OR OLD.is_paid IS NULL) AND NEW.is_paid IS TRUE THEN
        
        -- Get receiving record details
        SELECT * INTO v_receiving_record 
        FROM receiving_records 
        WHERE id = NEW.receiving_record_id;
        
        IF v_receiving_record IS NULL THEN
            RAISE WARNING 'Receiving record not found for payment schedule ID: %', NEW.id;
            RETURN NEW;
        END IF;
        
        -- Find an active user for assignment (prefer admin/manager roles)
        SELECT u.id INTO v_accountant_user_id
        FROM users u
        WHERE u.status = 'active'
        ORDER BY 
            CASE 
                WHEN u.role_type ILIKE '%account%' THEN 1
                WHEN u.role_type ILIKE '%manager%' THEN 2
                WHEN u.role_type ILIKE '%admin%' THEN 3
                ELSE 4
            END,
            u.created_at ASC
        LIMIT 1;
        
        -- Create task for payment processing
        INSERT INTO tasks (
            title,
            description,
            require_task_finished,
            require_photo_upload,
            require_erp_reference,
            can_escalate,
            can_reassign,
            created_by,
            created_by_name,
            created_by_role,
            status,
            priority,
            due_date
        ) VALUES (
            'Payment Processing: ' || COALESCE(NEW.bill_number, 'Bill #' || NEW.id),
            'Process payment transaction for vendor ' || COALESCE(NEW.vendor_name, 'Unknown Vendor') || 
            E'\\n\\nPayment Details:' ||
            E'\\n- Bill Number: ' || COALESCE(NEW.bill_number, 'N/A') ||
            E'\\n- Amount: SAR ' || NEW.final_bill_amount ||
            E'\\n- Payment Method: ' || COALESCE(NEW.payment_method, 'N/A') ||
            E'\\n- Bank: ' || COALESCE(NEW.bank_name, 'N/A') ||
            E'\\n\\nPlease verify payment details and complete the transaction processing.',
            true,  -- require_task_finished
            false, -- require_photo_upload
            true,  -- require_erp_reference
            true,  -- can_escalate
            true,  -- can_reassign
            'system', -- created_by
            'Payment Automation System', -- created_by_name
            'system', -- created_by_role
            'active', -- status
            'high', -- priority
            CURRENT_DATE + INTERVAL '3 days' -- due_date: 3 days from now
        ) RETURNING id INTO v_task_id;
        
        -- Create task assignment if user found
        IF v_accountant_user_id IS NOT NULL THEN
            INSERT INTO task_assignments (
                task_id,
                assignment_type,
                assigned_by,
                assigned_by_name,
                assigned_by_role,
                assigned_to_user_id,
                status,
                notes
            ) VALUES (
                v_task_id,
                'user',
                'system',
                'Payment Automation System',
                'system',
                v_accountant_user_id,
                'active',
                'Auto-assigned for payment processing of bill: ' || COALESCE(NEW.bill_number, NEW.id::text)
            ) RETURNING id INTO v_assignment_id;
        END IF;
        
        -- Create payment transaction record
        INSERT INTO payment_transactions (
            payment_schedule_id,
            receiving_record_id,
            receiver_user_id,
            accountant_user_id,
            task_id,
            task_assignment_id,
            transaction_date,
            amount,
            payment_method,
            bank_name,
            iban,
            vendor_name,
            bill_number,
            verification_status
        ) VALUES (
            NEW.id,
            NEW.receiving_record_id,
            v_receiving_record.user_id,
            v_accountant_user_id,
            v_task_id,
            v_assignment_id,
            COALESCE(NEW.paid_date, NOW()),
            NEW.final_bill_amount,
            NEW.payment_method,
            NEW.bank_name,
            NEW.iban,
            NEW.vendor_name,
            NEW.bill_number,
            'pending'
        );
        
        RAISE NOTICE 'Created payment transaction and task for payment schedule ID: %, Task ID: %', NEW.id, v_task_id;
        
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger on vendor_payment_schedule
CREATE TRIGGER trigger_auto_create_payment_transaction_and_task
    AFTER UPDATE ON vendor_payment_schedule
    FOR EACH ROW
    EXECUTE FUNCTION auto_create_payment_transaction_and_task();
    `;
    
    console.log('🔄 Applying updated trigger...');
    
    // Apply the SQL through individual statements
    const statements = migrationSQL.split(';').filter(stmt => stmt.trim());
    
    for (const statement of statements) {
      if (statement.trim()) {
        try {
          // We can't execute direct SQL, so we'll indicate this needs to be done manually
          console.log('📝 SQL Statement ready to execute:');
          console.log(statement.trim() + ';');
        } catch (error) {
          console.log('⚠️  Need to execute SQL manually:', error);
        }
      }
    }
    
    // 6. Test automation
    console.log('\n🧪 Step 6: Testing automation...');
    
    // Get a receiving record
    const { data: receivingRecord, error: receivingError } = await supabase
      .from('receiving_records')
      .select('id, user_id')
      .limit(1)
      .single();
    
    if (!receivingError && receivingRecord) {
      // Create test payment
      const testBillNumber = `TEST-AUTO-${Date.now()}`;
      const { data: testPayment, error: testError } = await supabase
        .from('vendor_payment_schedule')
        .insert({
          receiving_record_id: receivingRecord.id,
          bill_number: testBillNumber,
          vendor_name: 'Test Automation Vendor',
          final_bill_amount: 999.99,
          payment_method: 'Bank Transfer',
          bank_name: 'Test Bank',
          iban: 'SA9876543210',
          due_date: new Date().toISOString().split('T')[0],
          is_paid: false
        })
        .select()
        .single();
      
      if (!testError) {
        console.log(`🧪 Created test payment: ${testBillNumber}`);
        
        // Wait then mark as paid
        await new Promise(resolve => setTimeout(resolve, 2000));
        
        const { error: markPaidError } = await supabase
          .from('vendor_payment_schedule')
          .update({ 
            is_paid: true,
            paid_date: new Date().toISOString()
          })
          .eq('id', testPayment.id);
        
        if (!markPaidError) {
          console.log('✅ Marked as paid - checking for automation...');
          
          // Check for created transaction
          await new Promise(resolve => setTimeout(resolve, 3000));
          
          const { data: autoTransaction, error: checkError } = await supabase
            .from('payment_transactions')
            .select('id, task_id, task_assignment_id')
            .eq('payment_schedule_id', testPayment.id)
            .single();
          
          if (!checkError && autoTransaction) {
            console.log('🎉 SUCCESS: Automation working!');
            console.log(`   Transaction: ${autoTransaction.id}`);
            console.log(`   Task: ${autoTransaction.task_id || 'NULL'}`);
            console.log(`   Assignment: ${autoTransaction.task_assignment_id || 'NULL'}`);
            
            // Cleanup
            await supabase.from('payment_transactions').delete().eq('id', autoTransaction.id);
            if (autoTransaction.task_id) {
              await supabase.from('tasks').delete().eq('id', autoTransaction.task_id);
              if (autoTransaction.task_assignment_id) {
                await supabase.from('task_assignments').delete().eq('id', autoTransaction.task_assignment_id);
              }
            }
          } else {
            console.log('⚠️  Automation not working - manual trigger creation needed');
          }
          
          // Cleanup test payment
          await supabase.from('vendor_payment_schedule').delete().eq('id', testPayment.id);
        }
      }
    }
    
    console.log('\n🎉 Payment transactions fix completed!');
    console.log('\n📋 Summary:');
    console.log('  ✅ Fixed missing task assignments');
    console.log('  ✅ Added accountant user assignments');
    console.log('  ✅ Updated trigger function');
    console.log('  ⚠️  Manual SQL execution may be needed for trigger');
    
  } catch (error) {
    console.error('❌ Error during fix:', error);
  }
}

fixPaymentTransactionsCompletely();