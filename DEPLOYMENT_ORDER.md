# 🚀 Complete Database Deployment Guide

## ⚠️ Important: Deploy in Exact Order

Your Supabase database is missing columns that your frontend expects. Follow this **exact order** to fix it:

### Step 1: Deploy Enum Types (Required First!)
```sql
-- File: 38-enum-types-schema.sql
-- Deploy this FIRST - creates all enum types needed by tables
```

### Step 2: Deploy Core Schemas (In Order)
```sql
-- File: 01-app-functions-schema.sql
-- File: 02-branches-schema.sql
-- File: 03-employee-fine-payments-schema.sql
-- File: 04-employee-warning-history-schema.sql
-- File: 05-employee-warnings-schema.sql
-- File: 06-hr-departments-schema.sql
-- File: 07-hr-employee-contacts-schema.sql
-- File: 08-hr-employee-documents-schema.sql
-- File: 09-hr-employees-schema.sql
-- File: 10-hr-fingerprint-transactions-schema.sql
-- File: 11-hr-levels-schema.sql
-- File: 12-hr-position-assignments-schema.sql
-- File: 13-hr-position-reporting-template-schema.sql
-- File: 14-hr-positions-schema.sql
-- File: 15-hr-salary-components-schema.sql
-- File: 16-hr-salary-wages-schema.sql
-- File: 17-notification-attachments-schema.sql
-- File: 18-notification-queue-schema.sql
-- File: 19-notification-read-states-schema.sql
-- File: 20-notification-recipients-schema.sql
-- File: 21-notifications-schema.sql  ⭐ THIS FIXES YOUR CURRENT ERROR
-- File: 22-push-subscriptions-schema.sql
-- File: 23-recurring-assignment-schedules-schema.sql
-- File: 24-role-permissions-schema.sql
-- File: 25-task-assignments-schema.sql
-- File: 26-task-completions-schema.sql
-- File: 27-task-images-schema.sql
-- File: 28-tasks-schema.sql
-- File: 29-user-audit-logs-schema.sql
-- File: 30-user-device-sessions-schema.sql
-- File: 31-user-password-history-schema.sql
-- File: 32-user-roles-schema.sql
-- File: 33-user-sessions-schema.sql
-- File: 34-users-schema.sql
-- File: 35-vendors-schema.sql
```

### Step 3: Deploy Functions (Last!)
```sql
-- File: 37-database-functions-schema.sql
-- Deploy this LAST - creates all database functions and triggers
```

## 🎯 Current Error Analysis

**Error:** `Could not find the 'priority' column of 'notifications'`
**Cause:** Your Supabase notifications table is missing columns
**Fix:** Deploy `21-notifications-schema.sql` after `38-enum-types-schema.sql`

**Error:** `column notifications.status does not exist`
**Cause:** Same as above - missing schema deployment
**Fix:** Same deployment will add the `status` column

## ⚡ Quick Fix for Current Issue

If you want to fix JUST the notification error quickly:

1. **First**: Deploy `38-enum-types-schema.sql`
2. **Second**: Deploy `21-notifications-schema.sql`
3. **Third**: Deploy `37-database-functions-schema.sql`

This will restore your notification system functionality immediately.

## 📋 Deployment Checklist

- [ ] ✅ Deploy 38-enum-types-schema.sql
- [ ] ⏳ Deploy 21-notifications-schema.sql  
- [ ] ⏳ Deploy 37-database-functions-schema.sql
- [ ] ⏳ Test notification creation
- [ ] ⏳ Test push notifications
- [ ] ⏳ Deploy remaining schemas (01-35) as needed

## 🚨 Important Notes

1. **Order Matters**: Enums must exist before tables that use them
2. **CASCADE Warning**: The enum deployment will temporarily drop/recreate dependent tables
3. **Backup First**: Consider backing up your Supabase data before deployment
4. **Test After Each**: Verify each step works before proceeding

The frontend error will be resolved once the notifications table has the correct schema with `priority` and `status` columns.