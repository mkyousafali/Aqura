<script lang="ts">
	import { onMount } from 'svelte';
	import { _ as t } from '$lib/i18n';

	let supabase: any = null;
	let loading = true;
	let groups: any[] = [];
	let showForm = false;
	let editing: any = null;
	let saving = false;
	let showMembers = false;
	let selectedGroup: any = null;
	let members: any[] = [];
	let newMemberEmail = '';
	let newMemberName = '';

	let form = { group_name: '', group_type: 'static', description: '', is_dynamic: false };

	onMount(async () => {
		const mod = await import('$lib/utils/supabase');
		supabase = mod.supabase;
		await loadGroups();
	});

	async function loadGroups() {
		loading = true;
		try {
			const { data, error } = await supabase.rpc('get_email_groups');
			if (error) throw error;
			groups = data || [];
		} catch (err) { console.error(err); }
		finally { loading = false; }
	}

	function openCreate() { form = { group_name: '', group_type: 'static', description: '', is_dynamic: false }; editing = null; showForm = true; }
	function openEdit(g: any) { editing = g; form = { group_name: g.group_name, group_type: g.group_type || 'static', description: g.description || '', is_dynamic: g.is_dynamic }; showForm = true; }

	async function save() {
		saving = true;
		try {
			if (editing) {
				const { error } = await supabase.from('email_groups').update(form).eq('id', editing.id);
				if (error) throw error;
			} else {
				const { error } = await supabase.rpc('create_email_group', { p_data: form });
				if (error) throw error;
			}
			showForm = false;
			await loadGroups();
		} catch (err: any) { alert('Error: ' + err.message); }
		finally { saving = false; }
	}

	async function viewMembers(group: any) {
		selectedGroup = group;
		showMembers = true;
		const { data } = await supabase.from('email_group_members').select('*').eq('email_group_id', group.id).eq('is_active', true).order('email_address');
		members = data || [];
	}

	async function addMember() {
		if (!newMemberEmail || !selectedGroup) return;
		const { error } = await supabase.rpc('add_email_group_member', { p_group_id: selectedGroup.id, p_email_address: newMemberEmail, p_display_name: newMemberName || null });
		if (!error) { newMemberEmail = ''; newMemberName = ''; await viewMembers(selectedGroup); await loadGroups(); }
	}

	async function removeMember(memberId: string) {
		if (!selectedGroup) return;
		await supabase.rpc('remove_email_group_member', { p_group_id: selectedGroup.id, p_member_id: memberId });
		await viewMembers(selectedGroup);
		await loadGroups();
	}
</script>

<div class="email-groups">
	{#if loading}
		<div class="loading-container"><div class="loading-spinner"></div><p>Loading...</p></div>
	{:else if showMembers && selectedGroup}
		<div class="members-view">
			<div class="view-header">
				<h3>👥 {selectedGroup.group_name} — Members</h3>
				<button class="glass-btn" on:click={() => { showMembers = false; selectedGroup = null; }}>← Back</button>
			</div>
			<div class="add-member-row">
				<input type="email" bind:value={newMemberEmail} placeholder="email@example.com" />
				<input type="text" bind:value={newMemberName} placeholder="Name (optional)" />
				<button class="glass-btn primary" on:click={addMember} disabled={!newMemberEmail}>+ Add</button>
			</div>
			<div class="members-list">
				{#each members as member}
					<div class="member-item">
						<span class="member-email">{member.email_address}</span>
						<span class="member-name">{member.display_name || ''}</span>
						<button class="action-btn danger" on:click={() => removeMember(member.id)}>×</button>
					</div>
				{/each}
				{#if members.length === 0}<div class="empty-state">No members in this group.</div>{/if}
			</div>
		</div>
	{:else if showForm}
		<div class="form-container">
			<div class="form-header">
				<h3>{editing ? 'Edit' : 'Create'} Group</h3>
				<button class="glass-btn" on:click={() => showForm = false}>← Back</button>
			</div>
			<div class="form-body">
				<label><span>Group Name *</span><input type="text" bind:value={form.group_name} /></label>
				<label><span>Type</span>
					<select bind:value={form.group_type}>
						<option value="static">Static</option>
						<option value="customers">Customers</option>
						<option value="suppliers">Suppliers</option>
						<option value="employees">Employees</option>
						<option value="custom">Custom</option>
					</select>
				</label>
				<label><span>Description</span><textarea bind:value={form.description} rows="3"></textarea></label>
			</div>
			<div class="form-actions">
				<button class="glass-btn" on:click={() => showForm = false}>Cancel</button>
				<button class="glass-btn primary" on:click={save} disabled={saving || !form.group_name}>{saving ? 'Saving...' : 'Save'}</button>
			</div>
		</div>
	{:else}
		<div class="list-header">
			<h3>👥 Email Groups</h3>
			<button class="glass-btn primary" on:click={openCreate}>+ Create Group</button>
		</div>
		<div class="groups-grid">
			{#each groups as group}
				<div class="group-card">
					<div class="card-header"><strong>{group.group_name}</strong><span class="type-badge">{group.group_type}</span></div>
					{#if group.description}<p class="card-desc">{group.description}</p>{/if}
					<div class="card-meta"><span>{group.member_count || 0} members</span></div>
					<div class="card-actions">
						<button class="action-btn" on:click={() => viewMembers(group)}>👥 Members</button>
						<button class="action-btn" on:click={() => openEdit(group)}>✏️</button>
					</div>
				</div>
			{/each}
			{#if groups.length === 0}<div class="empty-state">No email groups yet.</div>{/if}
		</div>
	{/if}
</div>

<style>
	.email-groups { padding: 20px; height: 100%; overflow-y: auto; background: #f8fafc; }
	.loading-container { display: flex; flex-direction: column; align-items: center; justify-content: center; height: 200px; gap: 12px; color: #64748b; }
	.loading-spinner { width: 32px; height: 32px; border: 3px solid #e2e8f0; border-top-color: #f08300; border-radius: 50%; animation: spin 0.8s linear infinite; }
	@keyframes spin { to { transform: rotate(360deg); } }
	.list-header, .view-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
	.list-header h3, .view-header h3 { font-size: 16px; font-weight: 600; color: #1e293b; }
	.groups-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 12px; }
	.group-card { background: white; border-radius: 10px; padding: 14px; border: 1px solid #e2e8f0; }
	.card-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 4px; }
	.type-badge { font-size: 10px; background: #e0e7ff; color: #3730a3; padding: 2px 6px; border-radius: 4px; }
	.card-desc { font-size: 12px; color: #64748b; margin: 4px 0; }
	.card-meta { font-size: 12px; color: #94a3b8; margin-bottom: 8px; }
	.card-actions { display: flex; gap: 6px; }
	.add-member-row { display: flex; gap: 8px; margin-bottom: 12px; align-items: center; }
	.add-member-row input { padding: 8px 10px; border: 1px solid #e2e8f0; border-radius: 6px; font-size: 13px; flex: 1; }
	.members-list { display: flex; flex-direction: column; gap: 6px; }
	.member-item { display: flex; align-items: center; gap: 12px; padding: 8px 12px; background: white; border-radius: 6px; border: 1px solid #e2e8f0; font-size: 13px; }
	.member-email { font-weight: 500; flex: 1; }
	.member-name { color: #64748b; }
	.empty-state { text-align: center; color: #94a3b8; padding: 40px; grid-column: 1/-1; }
	.form-container { max-width: 500px; }
	.form-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
	.form-header h3 { font-size: 16px; font-weight: 600; }
	.form-body { display: flex; flex-direction: column; gap: 12px; background: white; padding: 16px; border-radius: 10px; border: 1px solid #e2e8f0; }
	.form-body label { display: flex; flex-direction: column; gap: 4px; font-size: 12px; color: #64748b; }
	.form-body label span { font-weight: 500; }
	.form-body input, .form-body select, .form-body textarea { padding: 8px 10px; border: 1px solid #e2e8f0; border-radius: 6px; font-size: 13px; }
	.form-actions { display: flex; justify-content: flex-end; gap: 10px; margin-top: 16px; }
	.action-btn { background: none; border: 1px solid #e2e8f0; border-radius: 6px; padding: 4px 10px; font-size: 12px; cursor: pointer; }
	.action-btn:hover { background: #f8fafc; }
	.action-btn.danger { color: #dc2626; }
	.action-btn.danger:hover { background: #fee2e2; }
	.glass-btn { padding: 8px 18px; border-radius: 8px; font-size: 13px; font-weight: 500; border: 1px solid rgba(255,255,255,0.3); cursor: pointer; background: rgba(255,255,255,0.7); backdrop-filter: blur(8px); box-shadow: 0 2px 8px rgba(0,0,0,0.06); transition: all 0.15s; color: #334155; }
	.glass-btn:hover { background: rgba(255,255,255,0.9); }
	.glass-btn:disabled { opacity: 0.5; cursor: not-allowed; }
	.glass-btn.primary { background: rgba(240,131,0,0.1); border-color: rgba(240,131,0,0.3); color: #c2410c; }
	.glass-btn.primary:hover { background: rgba(240,131,0,0.2); }
</style>
