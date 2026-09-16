<script>
  import { onMount } from 'svelte';
  import { supabase } from '$lib/utils/supabase';
  import { currentUser } from '$lib/utils/persistentAuth';

  const configurableTasks = [
    { number: 2, en: 'Follow Up Placing', ar: 'متابعة وضع المنتجات' },
    { number: 3, en: 'Warehouse Placing Confirmation', ar: 'تأكيد وضع المنتجات في المستودع' },
    { number: 4, en: 'Original Bill AI Check', ar: 'فحص الفاتورة الأصلية بالذكاء الاصطناعي' },
    { number: 5, en: 'PR Excel Upload', ar: 'رفع ملف PR Excel' },
    { number: 6, en: 'Pricing/Cost Verification', ar: 'التحقق من الأسعار والتكلفة' },
    { number: 7, en: 'Enter ERP Purchase Invoice Reference', ar: 'إدخال مرجع فاتورة المشتريات في ERP' },
    { number: 8, en: 'ERP Purchase Invoice Check', ar: 'فحص فاتورة المشتريات في ERP' },
    { number: 9, en: 'Get Advance Payment Approval', ar: 'الحصول على موافقة الدفعة المقدمة' },
    { number: 10, en: 'Final Receiving Verification', ar: 'التحقق النهائي من الاستلام' }
  ];

  let activeTab = 'list';
  let branches = [];
  let users = [];
  let selectedBranchId = '';
  let branchDropdownOpen = false;
  let loadingUsers = true;
  let loadError = '';
  let saveSuccess = '';
  let selectedUsersByTask = {};
  let ruleByTask = {};
  let savingTaskNumber = null;
  let userPickerTask = null;
  let userSearch = '';

  // Default assignees are global active users; branch membership is not required.
  $: branchUsers = selectedBranchId ? users : [];
  $: selectedBranch = branches.find((branch) => String(branch.id) === String(selectedBranchId));
  $: pickerUsers = userPickerTask
    ? branchUsers.filter((user) =>
        (user.username || '').toLowerCase().includes(userSearch.trim().toLowerCase())
      )
    : [];

  onMount(async () => {
    const [branchResult, userResult] = await Promise.all([
      supabase
        .from('branches')
        .select('id, name_en, name_ar, location_en, location_ar')
        .eq('is_active', true)
        .order('name_en'),
      supabase.from('users').select('id, username, branch_id, status').eq('status', 'active').order('username')
    ]);

    if (branchResult.error || userResult.error) {
      loadError = branchResult.error?.message || userResult.error?.message || 'Failed to load branches and users.';
    } else {
      branches = branchResult.data || [];
      users = userResult.data || [];
    }
    loadingUsers = false;
  });

  function assignmentKey(taskNumber) {
    return `${selectedBranchId}:${taskNumber}`;
  }

  function isUserSelected(taskNumber, userId) {
    return (selectedUsersByTask[assignmentKey(taskNumber)] || []).includes(userId);
  }

  async function persistUsers(taskNumber, userIds) {
    const rule = ruleByTask[taskNumber];
    if (!selectedBranchId || !rule || !$currentUser?.id) return false;
    savingTaskNumber = taskNumber;
    loadError = '';
    saveSuccess = '';
    const { data, error } = await supabase.rpc('Autotask_save_branch_config', {
      p_requesting_user_id: $currentUser.id,
      p_branch_id: String(selectedBranchId),
      p_rule_id: rule.rule_id,
      p_user_ids: userIds,
      p_is_enabled: true,
      p_expected_version: null
    });
    savingTaskNumber = null;
    if (error) {
      loadError = error.message || 'Failed to save default users.';
      await loadBranchConfig();
      return false;
    }
    const key = assignmentKey(taskNumber);
    selectedUsersByTask = {
      ...selectedUsersByTask,
      [key]: data?.default_user_ids || userIds
    };
    saveSuccess = `Default users for Task ${taskNumber} saved successfully.`;
    return true;
  }

  async function addUser(taskNumber, userId) {
    const key = assignmentKey(taskNumber);
    const selected = selectedUsersByTask[key] || [];
    if (selected.includes(userId)) return;
    selectedUsersByTask = {
      ...selectedUsersByTask,
      [key]: [...selected, userId]
    };
    const saved = await persistUsers(taskNumber, [...selected, userId]);
    if (saved) closeUserPicker();
  }

  async function removeUser(taskNumber, userId) {
    const key = assignmentKey(taskNumber);
    const next = (selectedUsersByTask[key] || []).filter((id) => id !== userId);
    selectedUsersByTask = {
      ...selectedUsersByTask,
      [key]: next
    };
    await persistUsers(taskNumber, next);
  }

  function openUserPicker(task) {
    userPickerTask = task;
    userSearch = '';
  }

  function closeUserPicker() {
    userPickerTask = null;
    userSearch = '';
  }

  async function loadBranchConfig() {
    if (!selectedBranchId) return;
    const { data, error } = await supabase.rpc('Autotask_get_branch_config', {
      p_branch_id: String(selectedBranchId)
    });
    if (error) {
      loadError = error.message || 'Failed to load Auto Task configuration.';
      return;
    }
    const next = { ...selectedUsersByTask };
    const rules = {};
    for (const row of data || []) {
      rules[row.task_number] = row;
      next[`${selectedBranchId}:${row.task_number}`] = row.default_user_ids || [];
    }
    ruleByTask = rules;
    selectedUsersByTask = next;
  }

  async function selectBranch(branchId) {
    selectedBranchId = String(branchId);
    branchDropdownOpen = false;
    closeUserPicker();
    saveSuccess = '';
    await loadBranchConfig();
  }
</script>

<div class="auto-task-manager">
  <div class="tab-bar">
    <button class:active={activeTab === 'list'} class="tab-button" type="button" on:click={() => (activeTab = 'list')}>Auto Task List</button>
    <button class:active={activeTab === 'users'} class="tab-button" type="button" on:click={() => (activeTab = 'users')}>Default User Management</button>
  </div>

  {#if activeTab === 'list'}
  <div class="tab-content" aria-label="Auto Task List">
    <div class="table-wrapper">
      <table>
        <thead>
          <tr>
            <th>#</th>
            <th>Task Name EN</th>
            <th>Task Name AR</th>
            <th>Trigger</th>
            <th>Auto Assigned To</th>
            <th>Condition to Close</th>
            <th>Timeline to Complete</th>
            <th>Push Notification Content EN</th>
            <th>Push Notification Content AR</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td>1</td>
            <td>Placing products on shelf</td>
            <td lang="ar" dir="rtl">وضع المنتجات على الرف</td>
            <td>Clearance certificate generated</td>
            <td>Selected user during the receiving process</td>
            <td>Upload a photo of the placed products</td>
            <td>24 hours</td>
            <td>
              Receiving date: &#123;&#123;receiving_date&#125;&#125;<br />
              Received by: &#123;&#123;received_by&#125;&#125;<br />
              Vendor name: &#123;&#123;vendor_name&#125;&#125;<br />
              Task name: &#123;&#123;task_name_en&#125;&#125;<br /><br />
              You have been assigned to place the products from “&#123;&#123;vendor_name&#125;&#125;” that were received
              on “&#123;&#123;receiving_date&#125;&#125;”. To complete this task, take a photo after placing the products,
              then close the task.
            </td>
            <td lang="ar" dir="rtl">
              تاريخ الاستلام: &#123;&#123;receiving_date&#125;&#125;<br />
              تم الاستلام بواسطة: &#123;&#123;received_by&#125;&#125;<br />
              اسم المورد: &#123;&#123;vendor_name&#125;&#125;<br />
              اسم المهمة: &#123;&#123;task_name_ar&#125;&#125;<br /><br />
              تم تعيينك لوضع منتجات المورد «&#123;&#123;vendor_name&#125;&#125;» التي تم استلامها بتاريخ
              «&#123;&#123;receiving_date&#125;&#125;». لإكمال هذه المهمة، التقط صورة بعد وضع المنتجات ثم أغلق المهمة.
            </td>
          </tr>
          <tr>
            <td>2</td>
            <td>Follow Up Placing</td>
            <td lang="ar" dir="rtl">متابعة وضع المنتجات</td>
            <td>Clearance certificate generated</td>
            <td>Default user assigned for the branch</td>
            <td>The assigned user must close the related “Placing products on shelf” task</td>
            <td>24 hours</td>
            <td>
              Receiving date: &#123;&#123;receiving_date&#125;&#125;<br />
              Received by: &#123;&#123;received_by&#125;&#125;<br />
              Vendor name: &#123;&#123;vendor_name&#125;&#125;<br />
              Task name: &#123;&#123;task_name_en&#125;&#125;<br /><br />
              You have been assigned to check the placement of products from
              “&#123;&#123;vendor_name&#125;&#125;” received on “&#123;&#123;receiving_date&#125;&#125;”. To
              complete this task, the related “Placing products on shelf” task must be completed.
            </td>
            <td lang="ar" dir="rtl">
              تاريخ الاستلام: &#123;&#123;receiving_date&#125;&#125;<br />
              تم الاستلام بواسطة: &#123;&#123;received_by&#125;&#125;<br />
              اسم المورد: &#123;&#123;vendor_name&#125;&#125;<br />
              اسم المهمة: &#123;&#123;task_name_ar&#125;&#125;<br /><br />
              تم تعيينك للتحقق من وضع منتجات المورد «&#123;&#123;vendor_name&#125;&#125;» المستلمة بتاريخ
              «&#123;&#123;receiving_date&#125;&#125;». لإكمال هذه المهمة، يجب إكمال مهمة «وضع المنتجات على
              الرف» المرتبطة بها.
            </td>
          </tr>
          <tr>
            <td>3</td>
            <td>Warehouse Placing Confirmation</td>
            <td lang="ar" dir="rtl">تأكيد وضع المنتجات في المستودع</td>
            <td>Clearance certificate generated</td>
            <td>Default user assigned for the branch</td>
            <td>
              The related “Placing products on shelf” task must be closed. Then select one:
              “Products have no balance remaining for the warehouse” or “Products have
              balance remaining for the warehouse.” If balance remains, a photo must also be uploaded.
            </td>
            <td>24 hours</td>
            <td>
              Receiving date: &#123;&#123;receiving_date&#125;&#125;<br />Received by: &#123;&#123;received_by&#125;&#125;<br />Vendor name: &#123;&#123;vendor_name&#125;&#125;<br />Task name: &#123;&#123;task_name_en&#125;&#125;<br /><br />
              You have been assigned to confirm the warehouse balance for products from “&#123;&#123;vendor_name&#125;&#125;” received on “&#123;&#123;receiving_date&#125;&#125;”. After the shelf-placement task is closed, select whether any warehouse balance remains. If stock remains, upload a photo before closing this task.
            </td>
            <td lang="ar" dir="rtl">
              تاريخ الاستلام: &#123;&#123;receiving_date&#125;&#125;<br />تم الاستلام بواسطة: &#123;&#123;received_by&#125;&#125;<br />اسم المورد: &#123;&#123;vendor_name&#125;&#125;<br />اسم المهمة: &#123;&#123;task_name_ar&#125;&#125;<br /><br />
              تم تعيينك لتأكيد رصيد المستودع لمنتجات المورد «&#123;&#123;vendor_name&#125;&#125;» المستلمة بتاريخ «&#123;&#123;receiving_date&#125;&#125;». بعد إغلاق مهمة وضع المنتجات على الرف، حدد ما إذا كان يوجد رصيد متبقٍ في المستودع. إذا كان هناك رصيد، ارفع صورة قبل إغلاق المهمة.
            </td>
          </tr>
          <tr>
            <td>4</td>
            <td>Original Bill AI Check</td>
            <td lang="ar" dir="rtl">فحص الفاتورة الأصلية بالذكاء الاصطناعي</td>
            <td>Clearance certificate generated</td>
            <td>Default user assigned for the branch</td>
            <td>
              Cannot be closed until the Original Bill AI check is Matched. The match status is read
              from <code>receiving_records.original_bill_check_result.status</code> and must equal
              <code>matched</code>.
            </td>
            <td>24 hours</td>
            <td>
              Receiving date: &#123;&#123;receiving_date&#125;&#125;<br />Received by: &#123;&#123;received_by&#125;&#125;<br />Vendor name: &#123;&#123;vendor_name&#125;&#125;<br />Task name: &#123;&#123;task_name_en&#125;&#125;<br /><br />
              You have been assigned to verify the original bill for “&#123;&#123;vendor_name&#125;&#125;”, received on “&#123;&#123;receiving_date&#125;&#125;”. Upload the original bill and run the AI check. This task can close only when the result is Matched.
            </td>
            <td lang="ar" dir="rtl">
              تاريخ الاستلام: &#123;&#123;receiving_date&#125;&#125;<br />تم الاستلام بواسطة: &#123;&#123;received_by&#125;&#125;<br />اسم المورد: &#123;&#123;vendor_name&#125;&#125;<br />اسم المهمة: &#123;&#123;task_name_ar&#125;&#125;<br /><br />
              تم تعيينك للتحقق من الفاتورة الأصلية للمورد «&#123;&#123;vendor_name&#125;&#125;» المستلمة بتاريخ «&#123;&#123;receiving_date&#125;&#125;». ارفع الفاتورة الأصلية وشغّل فحص الذكاء الاصطناعي. لا يمكن إغلاق المهمة إلا عندما تكون النتيجة «مطابقة».
            </td>
          </tr>
          <tr>
            <td>5</td>
            <td>PR Excel Upload</td>
            <td lang="ar" dir="rtl">رفع ملف PR Excel</td>
            <td>Clearance certificate generated</td>
            <td>Default user assigned for the branch</td>
            <td>
              Cannot be closed until a PR Excel file has been uploaded and exists on the receiving
              record.
            </td>
            <td>24 hours</td>
            <td>
              Receiving date: &#123;&#123;receiving_date&#125;&#125;<br />Received by: &#123;&#123;received_by&#125;&#125;<br />Vendor name: &#123;&#123;vendor_name&#125;&#125;<br />Task name: &#123;&#123;task_name_en&#125;&#125;<br /><br />
              You have been assigned to upload the PR Excel file for products from “&#123;&#123;vendor_name&#125;&#125;” received on “&#123;&#123;receiving_date&#125;&#125;”. Upload the PR Excel file to complete this task.
            </td>
            <td lang="ar" dir="rtl">
              تاريخ الاستلام: &#123;&#123;receiving_date&#125;&#125;<br />تم الاستلام بواسطة: &#123;&#123;received_by&#125;&#125;<br />اسم المورد: &#123;&#123;vendor_name&#125;&#125;<br />اسم المهمة: &#123;&#123;task_name_ar&#125;&#125;<br /><br />
              تم تعيينك لرفع ملف PR Excel لمنتجات المورد «&#123;&#123;vendor_name&#125;&#125;» المستلمة بتاريخ «&#123;&#123;receiving_date&#125;&#125;». ارفع ملف PR Excel لإكمال هذه المهمة.
            </td>
          </tr>
          <tr>
            <td>6</td>
            <td>Pricing/Cost Verification</td>
            <td lang="ar" dir="rtl">التحقق من الأسعار والتكلفة</td>
            <td>Clearance certificate generated</td>
            <td>Default user assigned for the branch</td>
            <td>
              Cannot be closed until the PR Excel verification checkbox is checked. The stored
              condition is <code>receiving_records.autotask_pr_excel_verified = true</code> for the
              receiving record.
            </td>
            <td>48 hours</td>
            <td>
              Receiving date: &#123;&#123;receiving_date&#125;&#125;<br />Received by: &#123;&#123;received_by&#125;&#125;<br />Vendor name: &#123;&#123;vendor_name&#125;&#125;<br />Task name: &#123;&#123;task_name_en&#125;&#125;<br /><br />
              You have been assigned to verify the pricing and cost for products from “&#123;&#123;vendor_name&#125;&#125;” received on “&#123;&#123;receiving_date&#125;&#125;”. Review the PR Excel and check the Verify box to complete this task.
            </td>
            <td lang="ar" dir="rtl">
              تاريخ الاستلام: &#123;&#123;receiving_date&#125;&#125;<br />تم الاستلام بواسطة: &#123;&#123;received_by&#125;&#125;<br />اسم المورد: &#123;&#123;vendor_name&#125;&#125;<br />اسم المهمة: &#123;&#123;task_name_ar&#125;&#125;<br /><br />
              تم تعيينك للتحقق من الأسعار والتكلفة لمنتجات المورد «&#123;&#123;vendor_name&#125;&#125;» المستلمة بتاريخ «&#123;&#123;receiving_date&#125;&#125;». راجع ملف PR Excel وحدد مربع «تحقق» لإكمال المهمة.
            </td>
          </tr>
          <tr>
            <td>7</td>
            <td>Enter ERP Purchase Invoice Reference</td>
            <td lang="ar" dir="rtl">إدخال مرجع فاتورة المشتريات في ERP</td>
            <td>Clearance certificate generated</td>
            <td>Default user assigned for the branch</td>
            <td>
              Cannot be closed until the ERP Purchase Invoice Reference field contains a value. The
              value is stored in <code>receiving_records.erp_purchase_invoice_reference</code>.
            </td>
            <td>24 hours</td>
            <td>
              Receiving date: &#123;&#123;receiving_date&#125;&#125;<br />Received by: &#123;&#123;received_by&#125;&#125;<br />Vendor name: &#123;&#123;vendor_name&#125;&#125;<br />Task name: &#123;&#123;task_name_en&#125;&#125;<br /><br />
              You have been assigned to enter the ERP Purchase Invoice Reference for “&#123;&#123;vendor_name&#125;&#125;”, received on “&#123;&#123;receiving_date&#125;&#125;”. Enter the ERP reference number to complete this task.
            </td>
            <td lang="ar" dir="rtl">
              تاريخ الاستلام: &#123;&#123;receiving_date&#125;&#125;<br />تم الاستلام بواسطة: &#123;&#123;received_by&#125;&#125;<br />اسم المورد: &#123;&#123;vendor_name&#125;&#125;<br />اسم المهمة: &#123;&#123;task_name_ar&#125;&#125;<br /><br />
              تم تعيينك لإدخال مرجع فاتورة المشتريات في ERP للمورد «&#123;&#123;vendor_name&#125;&#125;» المستلمة بتاريخ «&#123;&#123;receiving_date&#125;&#125;». أدخل رقم مرجع ERP لإكمال المهمة.
            </td>
          </tr>
          <tr>
            <td>8</td>
            <td>ERP Purchase Invoice Check</td>
            <td lang="ar" dir="rtl">فحص فاتورة المشتريات في ERP</td>
            <td>Clearance certificate generated</td>
            <td>Default user assigned for the branch</td>
            <td>
              Requires the ERP Purchase Invoice Reference to be entered. Cannot be closed until the
              ERP Check status shows Matched, stored as
              <code>receiving_records.erp_check_result.status = matched</code>.
            </td>
            <td>24 hours</td>
            <td>
              Receiving date: &#123;&#123;receiving_date&#125;&#125;<br />Received by: &#123;&#123;received_by&#125;&#125;<br />Vendor name: &#123;&#123;vendor_name&#125;&#125;<br />Task name: &#123;&#123;task_name_en&#125;&#125;<br /><br />
              You have been assigned to check the ERP Purchase Invoice for “&#123;&#123;vendor_name&#125;&#125;”, received on “&#123;&#123;receiving_date&#125;&#125;”. Enter the ERP reference if needed and run the ERP Check. This task can close only when the result is Matched.
            </td>
            <td lang="ar" dir="rtl">
              تاريخ الاستلام: &#123;&#123;receiving_date&#125;&#125;<br />تم الاستلام بواسطة: &#123;&#123;received_by&#125;&#125;<br />اسم المورد: &#123;&#123;vendor_name&#125;&#125;<br />اسم المهمة: &#123;&#123;task_name_ar&#125;&#125;<br /><br />
              تم تعيينك لفحص فاتورة المشتريات في ERP للمورد «&#123;&#123;vendor_name&#125;&#125;» المستلمة بتاريخ «&#123;&#123;receiving_date&#125;&#125;». أدخل مرجع ERP عند الحاجة وشغّل الفحص. لا يمكن إغلاق المهمة إلا عندما تكون النتيجة «مطابقة».
            </td>
          </tr>
          <tr>
            <td>9</td>
            <td>Get Advance Payment Approval</td>
            <td lang="ar" dir="rtl">الحصول على موافقة الدفعة المقدمة</td>
            <td>Clearance certificate generated</td>
            <td>Default user assigned for the branch</td>
            <td>
              Cannot be closed until the related automatically created advance-payment approval
              request is either Approved or Rejected.
            </td>
            <td>48 hours</td>
            <td>
              Receiving date: &#123;&#123;receiving_date&#125;&#125;<br />Received by: &#123;&#123;received_by&#125;&#125;<br />Vendor name: &#123;&#123;vendor_name&#125;&#125;<br />Task name: &#123;&#123;task_name_en&#125;&#125;<br /><br />
              You have been assigned to follow up on the advance-payment approval request for “&#123;&#123;vendor_name&#125;&#125;”, received on “&#123;&#123;receiving_date&#125;&#125;”. This task can close when the related request is Approved or Rejected.
            </td>
            <td lang="ar" dir="rtl">
              تاريخ الاستلام: &#123;&#123;receiving_date&#125;&#125;<br />تم الاستلام بواسطة: &#123;&#123;received_by&#125;&#125;<br />اسم المورد: &#123;&#123;vendor_name&#125;&#125;<br />اسم المهمة: &#123;&#123;task_name_ar&#125;&#125;<br /><br />
              تم تعيينك لمتابعة طلب الموافقة على الدفعة المقدمة للمورد «&#123;&#123;vendor_name&#125;&#125;» المستلمة بتاريخ «&#123;&#123;receiving_date&#125;&#125;». يمكن إغلاق المهمة عندما تتم الموافقة على الطلب المرتبط أو رفضه.
            </td>
          </tr>
          <tr>
            <td>10</td>
            <td>Final Receiving Verification</td>
            <td lang="ar" dir="rtl">التحقق النهائي من الاستلام</td>
            <td>Clearance certificate generated</td>
            <td>Default user assigned for the branch</td>
            <td>
              Cannot be closed until automatic tasks 1 through 9 linked to the same receiving record
              are all closed.
            </td>
            <td>48 hours</td>
            <td>
              Receiving date: &#123;&#123;receiving_date&#125;&#125;<br />Received by: &#123;&#123;received_by&#125;&#125;<br />Vendor name: &#123;&#123;vendor_name&#125;&#125;<br />Task name: &#123;&#123;task_name_en&#125;&#125;<br /><br />
              You have been assigned to complete the final receiving verification for “&#123;&#123;vendor_name&#125;&#125;”, received on “&#123;&#123;receiving_date&#125;&#125;”. Review the receiving record. This task can close only after tasks 1 through 9 are all closed.
            </td>
            <td lang="ar" dir="rtl">
              تاريخ الاستلام: &#123;&#123;receiving_date&#125;&#125;<br />تم الاستلام بواسطة: &#123;&#123;received_by&#125;&#125;<br />اسم المورد: &#123;&#123;vendor_name&#125;&#125;<br />اسم المهمة: &#123;&#123;task_name_ar&#125;&#125;<br /><br />
              تم تعيينك لإكمال التحقق النهائي من الاستلام للمورد «&#123;&#123;vendor_name&#125;&#125;» المستلم بتاريخ «&#123;&#123;receiving_date&#125;&#125;». راجع سجل الاستلام. لا يمكن إغلاق المهمة إلا بعد إغلاق جميع المهام من 1 إلى 9.
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
  {:else}
    <div class="tab-content" aria-label="Default User Management">
      <div class="management-panel">
        <div class="management-heading">
          <div>
            <h2>Default User Management</h2>
            <p>Select one or more default users for every task in each branch.</p>
          </div>
          <div class="branch-selector">
            <span>Branch</span>
            <button
              class="branch-dropdown-button"
              type="button"
              aria-haspopup="listbox"
              aria-expanded={branchDropdownOpen}
              on:click={() => (branchDropdownOpen = !branchDropdownOpen)}
            >
              {#if selectedBranch}
                <span class="branch-option-name">{selectedBranch.name_en || selectedBranch.name_ar || selectedBranch.id}</span>
                <span class="branch-option-location">{selectedBranch.location_en || selectedBranch.location_ar || 'No location'}</span>
              {:else}
                <span class="branch-placeholder">Select branch</span>
              {/if}
              <span class="branch-chevron">▾</span>
            </button>
            {#if branchDropdownOpen}
              <div class="branch-dropdown-menu" role="listbox">
                {#each branches as branch}
                  <button
                    class:selected={String(branch.id) === String(selectedBranchId)}
                    class="branch-dropdown-option"
                    type="button"
                    role="option"
                    aria-selected={String(branch.id) === String(selectedBranchId)}
                    on:click={() => selectBranch(branch.id)}
                  >
                    <span class="branch-option-name">{branch.name_en || branch.name_ar || branch.id}</span>
                    <span class="branch-option-location">{branch.location_en || branch.location_ar || 'No location'}</span>
                  </button>
                {/each}
              </div>
            {/if}
          </div>
        </div>

        <div class="task-one-note">
          <strong>Task 1 — Placing products on shelf:</strong>
          excluded from default-user management. Its user must be selected during the receiving process.
        </div>

        {#if saveSuccess}
          <p class="state-message success" role="status">{saveSuccess}</p>
        {/if}

        {#if loadingUsers}
          <p class="state-message">Loading branches and users…</p>
        {:else if loadError}
          <p class="state-message error">{loadError}</p>
        {:else if !selectedBranchId}
          <p class="state-message">Select a branch to manage its default users.</p>
        {:else}
          <div class="management-table-wrapper">
            <table class="management-table">
              <thead>
                <tr>
                  <th>#</th>
                  <th>Task Name EN</th>
                  <th>Task Name AR</th>
                  <th>Default Users (multiple allowed)</th>
                </tr>
              </thead>
              <tbody>
                {#each configurableTasks as task}
                  <tr>
                    <td>{task.number}</td>
                    <td>{task.en}</td>
                    <td lang="ar" dir="rtl">{task.ar}</td>
                    <td>
                      {#if branchUsers.length === 0}
                        <span class="empty-users">No active users found.</span>
                      {:else}
                        <div class="selected-users">
                          {#each (selectedUsersByTask[`${selectedBranchId}:${task.number}`] || []) as selectedUserId}
                            {@const user = branchUsers.find((candidate) => candidate.id === selectedUserId)}
                            {#if user}
                              <div class="selected-user">
                                <span>{user.username}</span>
                                <button type="button" on:click={() => removeUser(task.number, user.id)} aria-label={`Remove ${user.username}`}>Remove</button>
                              </div>
                            {/if}
                          {/each}
                          {#if (selectedUsersByTask[`${selectedBranchId}:${task.number}`] || []).length === 0}
                            <span class="empty-users">No default users selected.</span>
                          {/if}
                          <button class="add-user-button" type="button" on:click={() => openUserPicker(task)}>+ Add User</button>
                        </div>
                      {/if}
                    </td>
                  </tr>
                {/each}
              </tbody>
            </table>
          </div>
          <p class="configuration-note">
            Each selected user represents a separate future task assignment when a new receiving is created. Automatic task creation is not implemented yet.
          </p>
        {/if}
      </div>

      {#if userPickerTask}
        <div class="user-picker-overlay" role="presentation" on:click={closeUserPicker}>
          <div class="user-picker-modal" role="dialog" aria-modal="true" aria-label="Add default users" on:click|stopPropagation>
            <div class="user-picker-header">
              <div>
                <h3>Add Default Users</h3>
                <p>Task {userPickerTask.number}: {userPickerTask.en}</p>
              </div>
              <button class="user-picker-close" type="button" on:click={closeUserPicker} aria-label="Close">×</button>
            </div>
            <input
              class="user-search-input"
              type="search"
              bind:value={userSearch}
              placeholder="Search users…"
              autofocus
            />
            <div class="user-search-results">
              {#if pickerUsers.length === 0}
                <p class="state-message">No matching users found in this branch.</p>
              {:else}
                {#each pickerUsers as user}
                  <div class="user-search-row">
                    <span>{user.username}</span>
                    {#if isUserSelected(userPickerTask.number, user.id)}
                      <button type="button" class="user-selected-button" disabled>Selected</button>
                    {:else}
                      <button type="button" class="user-add-result-button" on:click={() => addUser(userPickerTask.number, user.id)}>Add</button>
                    {/if}
                  </div>
                {/each}
              {/if}
            </div>
          </div>
        </div>
      {/if}
    </div>
  {/if}
</div>

<style>
  .auto-task-manager {
    width: 100%;
    height: 100%;
    display: flex;
    flex-direction: column;
    background: #f8fafc;
  }

  .tab-bar {
    display: flex;
    padding: 0.75rem 1rem 0;
    border-bottom: 1px solid #e2e8f0;
    background: #ffffff;
  }

  .tab-button {
    padding: 0.65rem 1.1rem;
    border: 1px solid #cbd5e1;
    border-bottom: none;
    border-radius: 0.5rem 0.5rem 0 0;
    background: #ffffff;
    color: #1e293b;
    font-size: 0.875rem;
    font-weight: 600;
    cursor: pointer;
  }

  .tab-button.active {
    color: #1d4ed8;
    border-color: #93c5fd;
  }

  .tab-content {
    flex: 1;
    min-height: 0;
    padding: 1rem;
    overflow: auto;
    background: #f8fafc;
  }

  .table-wrapper {
    overflow-x: auto;
    overflow-y: hidden;
    border: 1px solid #e2e8f0;
    border-radius: 0.75rem;
    background: #ffffff;
  }

  table {
    width: 100%;
    min-width: 2250px;
    border-collapse: collapse;
  }

  th,
  td {
    padding: 0.8rem 1rem;
    border-bottom: 1px solid #e2e8f0;
    text-align: left;
    vertical-align: top;
    font-size: 0.875rem;
  }

  th {
    background: #f1f5f9;
    color: #334155;
    font-weight: 700;
  }

  td {
    color: #475569;
  }

  tbody tr:last-child td {
    border-bottom: none;
  }

  .management-panel {
    border: 1px solid #e2e8f0;
    border-radius: 0.75rem;
    background: #ffffff;
    padding: 1rem;
  }

  .management-heading {
    display: flex;
    align-items: end;
    justify-content: space-between;
    gap: 1rem;
    margin-bottom: 1rem;
  }

  .management-heading h2 {
    margin: 0 0 0.25rem;
    color: #1e293b;
    font-size: 1.1rem;
  }

  .management-heading p,
  .configuration-note {
    margin: 0;
    color: #64748b;
    font-size: 0.85rem;
  }

  .branch-selector {
    position: relative;
    display: grid;
    gap: 0.35rem;
    min-width: 240px;
    color: #334155;
    font-size: 0.8rem;
    font-weight: 700;
  }

  .branch-dropdown-button {
    position: relative;
    display: grid;
    width: 100%;
    padding: 0.55rem 2rem 0.55rem 0.75rem;
    border: 1px solid #cbd5e1;
    border-radius: 0.5rem;
    background: #ffffff;
    color: #1e293b;
    text-align: left;
    cursor: pointer;
  }

  .branch-placeholder {
    padding: 0.25rem 0;
    color: #64748b;
    font-weight: 500;
  }

  .branch-chevron {
    position: absolute;
    top: 50%;
    right: 0.75rem;
    transform: translateY(-50%);
    color: #64748b;
  }

  .branch-dropdown-menu {
    position: absolute;
    z-index: 20;
    top: calc(100% + 0.35rem);
    right: 0;
    width: 100%;
    max-height: 300px;
    overflow-y: auto;
    border: 1px solid #cbd5e1;
    border-radius: 0.5rem;
    background: #ffffff;
    box-shadow: 0 12px 30px rgba(15, 23, 42, 0.14);
  }

  .branch-dropdown-option {
    display: grid;
    width: 100%;
    gap: 0.15rem;
    padding: 0.65rem 0.75rem;
    border: none;
    border-bottom: 1px solid #e2e8f0;
    background: #ffffff;
    text-align: left;
    cursor: pointer;
  }

  .branch-dropdown-option:last-child {
    border-bottom: none;
  }

  .branch-dropdown-option:hover,
  .branch-dropdown-option.selected {
    background: #eff6ff;
  }

  .branch-option-name {
    color: #1e293b;
    font-size: 0.85rem;
    font-weight: 700;
  }

  .branch-option-location {
    color: #64748b;
    font-size: 0.75rem;
    font-weight: 500;
  }

  .task-one-note {
    margin-bottom: 1rem;
    padding: 0.75rem;
    border: 1px solid #bfdbfe;
    border-radius: 0.5rem;
    background: #eff6ff;
    color: #1e40af;
    font-size: 0.85rem;
  }

  .management-table-wrapper {
    overflow-x: auto;
    border: 1px solid #e2e8f0;
    border-radius: 0.6rem;
  }

  table.management-table {
    min-width: 900px;
  }

  .selected-users {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 0.5rem;
  }

  .selected-user {
    display: inline-flex;
    align-items: center;
    gap: 0.35rem;
    padding: 0.35rem 0.55rem;
    border: 1px solid #bfdbfe;
    border-radius: 999px;
    background: #eff6ff;
    color: #334155;
    font-size: 0.8rem;
  }

  .selected-user button {
    border: none;
    background: transparent;
    color: #b91c1c;
    font-size: 0.72rem;
    font-weight: 700;
    cursor: pointer;
  }

  .add-user-button,
  .user-add-result-button {
    padding: 0.4rem 0.7rem;
    border: 1px solid #2563eb;
    border-radius: 0.45rem;
    background: #2563eb;
    color: #ffffff;
    font-size: 0.78rem;
    font-weight: 700;
    cursor: pointer;
  }

  .user-picker-overlay {
    position: fixed;
    z-index: 1000;
    inset: 0;
    display: grid;
    place-items: center;
    padding: 1rem;
    background: rgba(15, 23, 42, 0.48);
  }

  .user-picker-modal {
    width: min(520px, 100%);
    max-height: 75vh;
    display: flex;
    flex-direction: column;
    gap: 0.85rem;
    padding: 1rem;
    border-radius: 0.75rem;
    background: #ffffff;
    box-shadow: 0 24px 60px rgba(15, 23, 42, 0.25);
  }

  .user-picker-header {
    display: flex;
    justify-content: space-between;
    gap: 1rem;
  }

  .user-picker-header h3,
  .user-picker-header p {
    margin: 0;
  }

  .user-picker-header p {
    margin-top: 0.2rem;
    color: #64748b;
    font-size: 0.8rem;
  }

  .user-picker-close {
    border: none;
    background: transparent;
    color: #64748b;
    font-size: 1.5rem;
    cursor: pointer;
  }

  .user-search-input {
    width: 100%;
    padding: 0.65rem 0.75rem;
    border: 1px solid #cbd5e1;
    border-radius: 0.5rem;
    outline: none;
  }

  .user-search-input:focus {
    border-color: #2563eb;
    box-shadow: 0 0 0 3px rgba(37, 99, 235, 0.12);
  }

  .user-search-results {
    min-height: 100px;
    overflow-y: auto;
    border: 1px solid #e2e8f0;
    border-radius: 0.5rem;
  }

  .user-search-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 1rem;
    padding: 0.65rem 0.75rem;
    border-bottom: 1px solid #e2e8f0;
  }

  .user-search-row:last-child {
    border-bottom: none;
  }

  .user-selected-button {
    padding: 0.35rem 0.6rem;
    border: 1px solid #bbf7d0;
    border-radius: 0.4rem;
    background: #f0fdf4;
    color: #15803d;
    font-size: 0.75rem;
    font-weight: 700;
  }

  .state-message,
  .empty-users,
  .configuration-note {
    color: #64748b;
  }

  .state-message.error {
    color: #b91c1c;
  }
  .state-message.success {
    color: #166534;
    background: #dcfce7;
    border: 1px solid #86efac;
    border-radius: 8px;
    padding: 0.65rem 0.8rem;
  }

  .configuration-note {
    margin-top: 0.75rem;
  }
</style>
