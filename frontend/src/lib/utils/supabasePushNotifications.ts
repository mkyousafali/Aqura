// Supabase Edge Function caller for push notifications
import { supabase } from './supabase';

interface NotificationPayload {
	title: string;
	body: string;
	icon?: string;
	badge?: string;
	data?: any;
}

/**
 * Send push notification via Supabase Edge Function
 */
export async function sendPushNotification(
	userId: string, 
	payload: NotificationPayload
): Promise<boolean> {
	try {
		// Get all active push subscriptions for the user
		const { data: subscriptions, error: fetchError } = await supabase
			.from('push_subscriptions')
			.select('push_subscription')
			.eq('user_id', userId)
			.eq('is_active', true);

		if (fetchError) {
			console.error('Failed to fetch push subscriptions:', fetchError);
			return false;
		}

		if (!subscriptions || subscriptions.length === 0) {
			console.log('No active push subscriptions found for user:', userId);
			return false;
		}

		// Send notification to each device
		const results = await Promise.allSettled(
			subscriptions.map(async (sub) => {
				const { data, error } = await supabase.functions.invoke('send-push-notification', {
					body: {
						subscription: sub.push_subscription,
						payload
					}
				});

				if (error) {
					console.error('Edge function error:', error);
					throw error;
				}

				return data;
			})
		);

		// Check if at least one notification was sent successfully
		const successCount = results.filter(result => result.status === 'fulfilled').length;
		console.log(`Push notifications sent: ${successCount}/${subscriptions.length}`);

		return successCount > 0;

	} catch (error) {
		console.error('Failed to send push notification:', error);
		return false;
	}
}

/**
 * Send notification to multiple users
 */
export async function sendBulkPushNotifications(
	userIds: string[], 
	payload: NotificationPayload
): Promise<number> {
	let successCount = 0;

	await Promise.allSettled(
		userIds.map(async (userId) => {
			const success = await sendPushNotification(userId, payload);
			if (success) successCount++;
		})
	);

	return successCount;
}