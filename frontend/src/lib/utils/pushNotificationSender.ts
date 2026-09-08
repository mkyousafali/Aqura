/**
 * Push Notification Sender
 * Calls the Edge Function to send push notifications to users
 */

import { supabase } from './supabase';

export interface SendPushOptions {
  notificationId: string;
  userIds: string[];
  title: string;
  body: string;
  icon?: string;
  badge?: string;
  image?: string;
  url?: string;
  type?: string;
  data?: any;
}

/**
 * Send push notification to specific users
 */
export async function sendPushNotification(options: SendPushOptions): Promise<{
  success: boolean;
  sent?: number;
  failed?: number;
  error?: string;
}> {
  try {
    console.log('📤 [Push Sender] Sending push notification:', {
      notificationId: options.notificationId,
      userCount: options.userIds.length,
      title: options.title,
      body: options.body
    });

    const requestBody = {
      notificationId: options.notificationId,
      userIds: options.userIds,
      payload: {
        notificationId: options.notificationId,
        title: options.title,
        body: options.body,
        icon: options.icon,
        badge: options.badge,
        image: options.image,
        url: options.url,
        type: options.type,
        data: options.data
      }
    };

    console.log('📤 [Push Sender] Full request body:', JSON.stringify(requestBody, null, 2));

    const { data, error } = await supabase.functions.invoke('send-push-notification', {
      body: requestBody
    });

    if (error) {
      console.error('📤 [Push Sender] Error:', error);
      return {
        success: false,
        error: error.message
      };
    }

    console.log('📤 [Push Sender] ✅ Success:', data);
    return {
      success: true,
      sent: data.sent,
      failed: data.failed
    };
  } catch (error) {
    console.error('📤 [Push Sender] Exception:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error'
    };
  }
}

/**
 * Send push notification for a specific notification ID
 * Automatically fetches the recipient users from notification_recipients table
 */
export async function sendPushForNotification(
  notificationId: string,
  title: string,
  body: string,
  options?: {
    url?: string;
    type?: string;
    icon?: string;
    image?: string;
  }
): Promise<{ success: boolean; sent?: number; error?: string }> {
  try {
    console.log('📤 [Push Sender] Fetching recipients for notification:', notificationId);

    // Get recipients for this notification
    const { data: recipients, error: recipientsError } = await supabase
      .from('notification_recipients')
      .select('user_id')
      .eq('notification_id', notificationId);

    if (recipientsError) {
      console.error('📤 [Push Sender] Error fetching recipients:', recipientsError);
      return {
        success: false,
        error: 'Failed to fetch recipients'
      };
    }

    if (!recipients || recipients.length === 0) {
      console.log('📤 [Push Sender] No recipients found');
      return {
        success: true,
        sent: 0
      };
    }

    const userIds = recipients.map(r => r.user_id);
    console.log('📤 [Push Sender] Found', userIds.length, 'recipients');

    // Send push notification
    return await sendPushNotification({
      notificationId,
      userIds,
      title,
      body,
      url: options?.url,
      type: options?.type,
      icon: options?.icon,
      image: options?.image
    });
  } catch (error) {
    console.error('📤 [Push Sender] Exception:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error'
    };
  }
}
