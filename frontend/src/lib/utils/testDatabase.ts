import { supabase } from '../utils/supabase';
import { userAuth } from '../utils/userAuth';

/**
 * Test database connection and authentication
 */
export async function testDatabaseConnection() {
	console.log('🔍 Testing database connection...');
	
	try {
		// Test 1: Basic connection
		const { count, error } = await supabase
			.from('users')
			.select('*', { count: 'exact', head: true });

		if (error) {
			console.error('❌ Database connection failed:', error);
			return false;
		}

		console.log('✅ Database connection successful');
		console.log(`📊 Total users in database: ${count}`);

		// Test 2: Check if views exist
		const { data: viewData, error: viewError } = await supabase
			.from('user_management_view')
			.select('*')
			.limit(1);

		if (viewError) {
			console.error('❌ User management view not accessible:', viewError);
			return false;
		}

		console.log('✅ User management view is accessible');

		// Test 3: Try to authenticate with default master admin
		console.log('🔑 Testing default master admin authentication...');
		
		try {
			const { user, token } = await userAuth.loginWithCredentials('madmin', '@Madmin709');
			console.log('✅ Master admin authentication successful');
			console.log('👤 User:', user.username, '- Role:', user.role);
			console.log('🎫 Token:', token.substring(0, 20) + '...');
			
			// Test logout
			await userAuth.logout(token);
			console.log('✅ Logout successful');
			
		} catch (authError) {
			console.error('❌ Master admin authentication failed:', authError);
			return false;
		}

		// Test 4: Try quick access code
		console.log('🚀 Testing quick access authentication...');
		
		try {
			const { user: qaUser, token: qaToken } = await userAuth.loginWithQuickAccess('491709');
			console.log('✅ Quick access authentication successful');
			console.log('👤 User:', qaUser.username, '- Role:', qaUser.role);
			
			// Test logout
			await userAuth.logout(qaToken);
			console.log('✅ Quick access logout successful');
			
		} catch (qaError) {
			console.error('❌ Quick access authentication failed:', qaError);
			return false;
		}

		console.log('🎉 All database tests passed!');
		return true;

	} catch (error) {
		console.error('❌ Unexpected error during database test:', error);
		return false;
	}
}

/**
 * Test user management functions
 */
export async function testUserManagement() {
	console.log('🔍 Testing user management functions...');

	try {
		const { userManagement } = await import('../utils/userManagement');

		// Test 1: Get all users
		const users = await userManagement.getAllUsers();
		console.log(`✅ Retrieved ${users.length} users`);

		// Test 2: Get user roles
		const roles = await userManagement.getUserRoles();
		console.log(`✅ Retrieved ${roles.length} user roles`);

		// Test 3: Get branches
		const branches = await userManagement.getBranches();
		console.log(`✅ Retrieved ${branches.length} branches`);

		// Test 4: Check username availability
		const isAvailable = await userManagement.isUsernameAvailable('test-user-' + Date.now());
		console.log('✅ Username availability check:', isAvailable);

		// Test 5: Quick access code stats
		const stats = await userManagement.getQuickAccessStats();
		console.log('✅ Quick access code stats:', stats);

		console.log('🎉 All user management tests passed!');
		return true;

	} catch (error) {
		console.error('❌ User management test failed:', error);
		return false;
	}
}

/**
 * Run all tests
 */
export async function runAllTests() {
	console.log('🚀 Starting comprehensive database integration tests...\n');

	const dbTest = await testDatabaseConnection();
	console.log('\n');
	
	const userMgmtTest = await testUserManagement();
	console.log('\n');

	if (dbTest && userMgmtTest) {
		console.log('🎉✨ All tests passed! Database integration is working correctly! ✨🎉');
		return true;
	} else {
		console.log('❌💥 Some tests failed. Check the logs above for details. 💥❌');
		return false;
	}
}