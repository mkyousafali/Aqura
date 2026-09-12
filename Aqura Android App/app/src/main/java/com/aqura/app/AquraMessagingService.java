package com.aqura.app;

import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Intent;
import android.graphics.Color;
import android.os.Build;

import androidx.core.app.NotificationCompat;

import com.google.firebase.messaging.FirebaseMessagingService;
import com.google.firebase.messaging.RemoteMessage;

public final class AquraMessagingService extends FirebaseMessagingService {
    private static final String CHANNEL_ID = "aqura_notifications";

    @Override public void onMessageReceived(RemoteMessage message) {
        String title = value(message, "title", "Aqura");
        String body = value(message, "body", "You have a new notification");
        String path = value(message, "url", "");

        Intent intent = new Intent(this, MainActivity.class)
                .setAction(Intent.ACTION_VIEW)
                .setData(android.net.Uri.parse("aqura://open?path=" + android.net.Uri.encode(path)))
                .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_SINGLE_TOP);
        PendingIntent pendingIntent = PendingIntent.getActivity(
                this, message.getMessageId() == null ? 0 : message.getMessageId().hashCode(), intent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);

        NotificationManager manager = getSystemService(NotificationManager.class);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                    CHANNEL_ID, "Aqura notifications", NotificationManager.IMPORTANCE_HIGH);
            channel.setDescription("Tasks, assignments, and Aqura alerts");
            channel.enableLights(true);
            channel.setLightColor(Color.rgb(240, 131, 0));
            manager.createNotificationChannel(channel);
        }

        NotificationCompat.Builder notification = new NotificationCompat.Builder(this, CHANNEL_ID)
                .setSmallIcon(com.aqura.app.R.mipmap.ic_launcher)
                .setContentTitle(title)
                .setContentText(body)
                .setStyle(new NotificationCompat.BigTextStyle().bigText(body))
                .setAutoCancel(true)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setContentIntent(pendingIntent);
        manager.notify(message.getMessageId() == null ? (int) System.currentTimeMillis() : message.getMessageId().hashCode(), notification.build());
    }

    private static String value(RemoteMessage message, String key, String fallback) {
        String value = message.getData().get(key);
        return value == null || value.isBlank() ? fallback : value;
    }
}
