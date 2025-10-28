# Requisition Approval Notification Feature

## Overview
Automatically sends in-app and push notifications to the selected approver when a new expense requisition is generated and saved through the Request Generator.

## Implementation Date
January 29, 2025

## Feature Description
When a user creates an expense requisition through the Request Generator:
1. The requisition is saved to the database
2. A notification is automatically sent to the selected approver
3. The notification appears in the approver's Notification Center
4. If the approver has push notifications enabled, they also receive a push notification

## How It Works

### User Flow
1. **Requester** fills out the requisition form in Request Generator:
   - Selects branch
   - Enters amount
   - **Selects approver** (crucial step)
   - Selects expense category
   - Fills in requester details
   - Adds description

2. **System** generates the requisition template

3. **System** saves the requisition to database

4. **System** automatically sends notification to the selected approver:
   - Notification title: "New Expense Requisition for Approval"
   - Notification message includes:
     - Requisition number
     - Submitted by (username or requester name)
     - Branch name
     - Amount in SAR
     - Expense category
   - Priority: High (if amount > 10,000 SAR), otherwise Medium
   - Type: Info
   - Target: Specific user (the selected approver)

5. **Approver** receives the notification:
   - Sees notification in Notification Center
   - Gets push notification (if enabled)
   - Can click to view details in Approval Center

### Notification Details

**Notification Message Format:**
```
Title: New Expense Requisition for Approval

Message: A new expense requisition (REQ-20250129-1234) has been submitted 
for your approval by john_doe. Branch: Main Office - المكتب الرئيسي, 
Amount: 15,500.00 SAR, Category: Office Supplies
```

**Priority Logic:**
- **High Priority**: Amount > 10,000 SAR
- **Medium Priority**: Amount ≤ 10,000 SAR

**Notification Type:**
- Type: `info` (informational notification)
- Target Type: `specific_users` (only the selected approver)

## Technical Implementation

### Files Modified

#### 1. `frontend/src/lib/components/admin/finance/RequestGenerator.svelte`

**Changes Made:**

1. **Import notification service:**
```javascript
import { notificationService } from '$lib/utils/notificationManagement';
```

2. **Added notification sending after database save:**
```javascript
// After requisition is saved to database (80-95%)
savingProgress = 95;
savingStatus = 'Sending notification to approver...';

// Send notification to the selected approver
try {
    if (selectedApproverId && selectedApproverName) {
        await notificationService.createNotification({
            title: 'New Expense Requisition for Approval',
            message: `A new expense requisition (${requisitionNumber}) has been submitted for your approval by ${$currentUser?.username || requesterName}. Branch: ${getBranchName()}, Amount: ${parseFloat(amount).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} SAR, Category: ${selectedCategoryName.en}`,
            type: 'info',
            priority: parseFloat(amount) > 10000 ? 'high' : 'medium',
            target_type: 'specific_users',
            target_users: [selectedApproverId]
        }, $currentUser?.id || $currentUser?.username || 'System');
        
        console.log('✅ Notification sent to approver:', selectedApproverName);
    }
} catch (notifError) {
    console.error('❌ Failed to send notification to approver:', notifError);
    // Don't throw error - notification failure shouldn't stop requisition creation
}
```

### Error Handling
- Notification failures are logged but don't prevent requisition creation
- If notification sending fails, the requisition is still saved successfully
- User is notified of requisition save success regardless of notification status

## Notification System Integration

### Backend Support
The notification system uses:
- **Notification Management Service**: Handles creation and distribution of notifications
- **Notification Queue**: Queues notifications for delivery
- **Push Notification Processor**: Processes push notifications
- **Database Triggers**: Automatically create notification recipients

### Database Tables Used
1. `notifications` - Stores the notification details
2. `notification_recipients` - Links notifications to target users
3. `notification_queue` - Queues push notifications for delivery
4. `notification_read_states` - Tracks read/unread status

## User Experience

### For Requester (Person Creating Requisition)
1. Fills out requisition form
2. Selects approver from dropdown
3. Clicks "Save Requisition"
4. Sees progress:
   - Preparing template... (0-30%)
   - Capturing image... (30-40%)
   - Uploading image... (40-70%)
   - Getting image URL... (70-80%)
   - Saving to database... (80-95%)
   - **Sending notification to approver...** (95%)
   - Completed! (100%)
5. Receives success message

### For Approver (Person Receiving Notification)
1. Receives in-app notification in Notification Center
2. Receives push notification (if enabled)
3. Notification includes all key information
4. Can click notification to navigate to Approval Center
5. Can review and approve/reject the requisition

## Testing Checklist

- [ ] Create a requisition with amount < 10,000 SAR
  - [ ] Verify medium priority notification is sent
  - [ ] Verify approver receives notification
  - [ ] Check notification appears in Notification Center
  
- [ ] Create a requisition with amount > 10,000 SAR
  - [ ] Verify high priority notification is sent
  - [ ] Verify approver receives notification with high priority
  
- [ ] Test with different approvers
  - [ ] Verify correct approver receives notification
  - [ ] Verify only the selected approver receives notification
  
- [ ] Test push notifications
  - [ ] Verify push notification is sent if approver has it enabled
  - [ ] Check push notification content is correct
  
- [ ] Test error scenarios
  - [ ] Verify requisition still saves if notification fails
  - [ ] Check error is logged but doesn't stop process
  
- [ ] Test notification content
  - [ ] Verify requisition number is correct
  - [ ] Verify branch name is displayed
  - [ ] Verify amount is formatted correctly
  - [ ] Verify category name is shown

## Benefits

1. **Immediate Notification**: Approvers are notified instantly when a requisition needs their attention
2. **Reduced Delays**: No need to manually inform approvers
3. **Complete Information**: Notification includes all key details at a glance
4. **Priority Handling**: High-value requisitions get high priority notifications
5. **Audit Trail**: All notifications are logged in the system
6. **Multi-channel**: Both in-app and push notifications (if enabled)

## Future Enhancements

### Potential Additions:
1. **Email Notifications**: Send email to approver (requires email service setup)
2. **SMS Notifications**: Send SMS for urgent requisitions
3. **Reminder Notifications**: Send reminders if requisition not reviewed after X hours
4. **Status Change Notifications**: Notify requester when requisition is approved/rejected
5. **Escalation**: Auto-escalate to higher approver if not reviewed within timeframe
6. **Batch Notifications**: Group multiple requisitions in one notification
7. **Custom Templates**: Allow admins to customize notification messages
8. **Notification Preferences**: Let users choose which notifications they want to receive

## Related Files

- `frontend/src/lib/components/admin/finance/RequestGenerator.svelte` - Main component
- `frontend/src/lib/utils/notificationManagement.ts` - Notification service
- `frontend/src/lib/components/admin/finance/ApprovalCenter.svelte` - Where approvers review requisitions
- `frontend/src/routes/mobile/approval-center/+page.svelte` - Mobile approval interface

## Configuration

### Notification Settings
- **Default Priority**: Medium
- **High Priority Threshold**: Amount > 10,000 SAR
- **Notification Type**: Info
- **Target Type**: Specific Users (approver only)
- **Auto-send**: Enabled (sent immediately after save)

## Notes

- Notification is sent **after** the requisition is successfully saved to the database
- If approver ID is not set, no notification is sent (silent failure)
- Notification sending happens at 95% of the save progress
- Current user info is used as the "created by" for the notification
- The notification system handles push notification queuing automatically
