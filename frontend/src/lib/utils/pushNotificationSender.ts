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
 * Automatically fetches the recipient users from notification_recipients table.
 *
 * When `langVariants` is supplied, recipients are split by their own
 * `users.default_language` and each group gets its own title/body — so a
 * push arrives only in the recipient's preferred language. Recipients with
 * no preference set (or when `langVariants` is omitted entirely) fall back
 * to the single combined `title`/`body` passed in, exactly as before.
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
  },
  langVariants?: {
    titleEn?: string;
    bodyEn?: string;
    titleAr?: string;
    bodyAr?: string;
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

    const hasLangVariants =
      langVariants && (langVariants.titleEn || langVariants.titleAr || langVariants.bodyEn || langVariants.bodyAr);

    if (!hasLangVariants) {
      // No per-language content supplied — original single-payload behavior.
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
    }

    // Bucket recipients by their own default_language.
    const { data: userLangs, error: userLangsError } = await supabase
      .from('users')
      .select('id, default_language')
      .in('id', userIds);

    if (userLangsError) {
      console.warn('📤 [Push Sender] Could not look up recipient languages, falling back to combined payload:', userLangsError);
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
    }

    const langById = new Map((userLangs || []).map((u) => [u.id, u.default_language]));
    const enIds: string[] = [];
    const arIds: string[] = [];
    const fallbackIds: string[] = [];

    for (const id of userIds) {
      const lang = langById.get(id);
      if (lang === 'en') enIds.push(id);
      else if (lang === 'ar') arIds.push(id);
      else fallbackIds.push(id);
    }

    let sent = 0;
    let lastError: string | undefined;

    const groups: Array<{ ids: string[]; t: string; b: string }> = [
      { ids: enIds, t: langVariants!.titleEn || title, b: langVariants!.bodyEn || body },
      { ids: arIds, t: langVariants!.titleAr || title, b: langVariants!.bodyAr || body },
      { ids: fallbackIds, t: title, b: body },
    ];

    for (const group of groups) {
      if (group.ids.length === 0) continue;
      const result = await sendPushNotification({
        notificationId,
        userIds: group.ids,
        title: group.t,
        body: group.b,
        url: options?.url,
        type: options?.type,
        icon: options?.icon,
        image: options?.image
      });
      if (result.success) {
        sent += result.sent || 0;
      } else {
        lastError = result.error;
      }
    }

    return lastError && sent === 0 ? { success: false, error: lastError } : { success: true, sent };
  } catch (error) {
    console.error('📤 [Push Sender] Exception:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error'
    };
  }
}
