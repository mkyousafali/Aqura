# WhatsApp Business Manager — Full Implementation Plan

## 📍 Sidebar Location
- **New top-level section** in sidebar: 📱 **WhatsApp**
- Permission code: `WHATSAPP_DASHBOARD`, `WHATSAPP_LIVE_CHAT`, `WHATSAPP_BROADCASTS`, `WHATSAPP_TEMPLATES`, `WHATSAPP_CONTACTS`, `WHATSAPP_AI_BOT`, `WHATSAPP_AUTO_REPLY_BOT`, `WHATSAPP_ACCOUNTS`, `WHATSAPP_SETTINGS`

## 🎨 Design Style
- Matches **ShiftAndDayOff.svelte** design pattern
- Light background: `bg-[#f8fafc]`
- White header bar with pill-style tab navigation (`bg-slate-100 rounded-2xl`)
- Active tabs: colored backgrounds with shadows (green/emerald for WhatsApp)
- Main content: radial gradient background with decorative blur circles
- Glass cards: `bg-white/40 backdrop-blur-xl rounded-[2.5rem]`
- Accent color: **Emerald/Green** (WhatsApp brand)
- RTL support via `dir={$locale === 'ar' ? 'rtl' : 'ltr'}`

---

## 🪟 Windows (9 total)

### 1. 📊 WhatsApp Dashboard
**File:** `frontend/src/lib/components/desktop-interface/whatsapp/WADashboard.svelte`
**Window Size:** 1200×700

**Content:**
- **Account Status Card** — connected number, verified status, quality rating (🟢🟡🔴)
- **Today's Stats Cards** — messages sent, delivered, read, failed (with percentages)
- **Weekly/Monthly Chart** — message volume over time (bar chart)
- **Recent Activity** — last 10 messages sent/received with status indicators
- **Template Performance** — which templates have best open/reply rates
- **AI Bot Stats** — messages auto-handled vs escalated to human
- **Auto-Reply Bot Stats** — triggers matched, conversations handled

---

### 2. 💬 WhatsApp Live Chat
**File:** `frontend/src/lib/components/desktop-interface/whatsapp/WALiveChat.svelte`
**Window Size:** 1400×800

**Content:**
- **Left Panel — Conversation List:**
  - Customer name + WhatsApp number
  - Last message preview + timestamp
  - Unread count badge
  - 🟢/🔴 24hr window status with customer name
  - Search by name/number
  - Filter: All / Unread / AI-handled / Bot-handled / Human

- **Right Panel — Chat Thread:**
  - Message bubbles (sent = green right, received = white left)
  - Message status: sent ✓, delivered ✓✓, read ✓✓ blue
  - Input box with send button
  - Attach: image, document, file
  - Send template button (opens template picker)
  - "Take over from AI/Bot" button if automated reply is active

- **Customer Info Sidebar (toggleable):**
  - Name, WhatsApp number, registration date
  - 24hr window status
  - Order history link
  - Quick actions

---

### 3. 📢 WhatsApp Broadcasts
**File:** `frontend/src/lib/components/desktop-interface/whatsapp/WABroadcasts.svelte`
**Window Size:** 1200×700

**Tabs:**
- **Create Broadcast:**
  - Template picker (only Approved templates, NO rejected)
  - Live mobile phone preview of selected template
  - Recipient selection:
    - 🟢 Inside 24hrs only
    - 🔴 Outside 24hrs only
    - 📤 Send to All
    - Custom filter (by name, group, etc.)
  - Import recipients from Excel/CSV
  - Schedule or send immediately
  
- **Broadcast History:**
  - List of past broadcasts: date, template, total recipients, delivered, read, failed
  - Click to see per-recipient delivery status

- **Recipient Groups:**
  - Create/manage saved groups (e.g., "VIP Customers", "New This Month")
  - Add/remove customers from groups

---

### 4. 📝 Template Manager
**File:** `frontend/src/lib/components/desktop-interface/whatsapp/WATemplates.svelte`
**Window Size:** 1200×700

**Content:**
- **Template List:**
  - All Meta templates with status: Approved ✅, Pending ⏳
  - Rejected templates hidden (not shown)
  - Filter by category, language, status

- **Create Template Form:**
  - Category: Marketing / Utility / Authentication
  - Language: EN / AR
  - Header: text, image, video, or document
  - Body: text with `{{1}}`, `{{2}}` variables
  - Footer: optional text
  - Buttons: URL button, phone call button, quick reply
  - Submit to Meta for approval

- **Live Mobile Preview:**
  - Real-time phone mockup showing exactly how the template will look
  - Updates as you type

- **Actions:** Edit, Duplicate, Delete templates

---

### 5. 👥 WhatsApp Contacts
**File:** `frontend/src/lib/components/desktop-interface/whatsapp/WAContacts.svelte`
**Window Size:** 1200×700

**Content:**
- **Contact List Table:**
  - Customer name
  - WhatsApp number
  - 🟢/🔴 24hr window status badge WITH customer name
  - Last message time
  - Unread message count
  - Auto-synced from `customers` table

- **Search & Filter:**
  - By name, number
  - By 24hr status (inside/outside)
  - Has unread messages

- **Click Contact → Message History:**
  - Full conversation history with that customer
  - Quick actions: send template, open live chat, view profile/orders

---

### 6. 🤖 WhatsApp AI Bot
**File:** `frontend/src/lib/components/desktop-interface/whatsapp/WAaiBot.svelte`
**Window Size:** 1200×700

**Content:**
- **Global On/Off Toggle** — enable/disable AI auto-replies
- **API Key Status** — ✅ Key configured / ❌ Key not found (key stored in Vercel env vars & server .env, NOT in UI)
- **Training Data Section:**
  - Product catalog info
  - Business policies (returns, delivery, hours)
  - FAQs
  - Custom instructions (e.g., "always greet in Arabic first")
  - Add/edit/delete training entries

- **Tone & Personality:**
  - Formal / Friendly / Professional
  - Bilingual AR/EN auto-detect

- **Handoff Rules:**
  - Escalate to human when: complaints, order issues, specific keywords
  - Max replies per conversation before auto-escalate

- **Conversation Log:**
  - All AI-handled conversations
  - Customer name, messages, escalation status
  - Filter: handled / escalated / active

- **Response Limits:**
  - Max replies per conversation
  - Cooldown period

---

### 7. 🔧 Auto-Reply Bot Builder
**File:** `frontend/src/lib/components/desktop-interface/whatsapp/WAAutoReplyBot.svelte`
**Window Size:** 1300×750

**Content:**
- **Global On/Off Toggle**
- **Priority Setting** — runs BEFORE AI Bot (Auto-Reply takes priority)

- **Trigger List Table:**
  - Trigger words/phrases (AR & EN)
  - Match type: exact / contains / starts with
  - Reply type: text / image / file / template / buttons / links
  - Reply preview
  - Active/Inactive toggle per trigger

- **Create/Edit Trigger Form:**
  - Trigger words (comma-separated, both Arabic & English)
  - Match type selector
  - Reply builder:
    - Text reply
    - Attach image/file
    - Send preset Meta template (picker)
    - Add clickable buttons (quick reply)
    - Add URL buttons (open link)
    - Add call buttons (tap to call)
    - Add links
  - Follow-up flow: if customer clicks button → define next reply

- **Flow Builder:**
  - Visual tree showing conversation paths
  - Drag and drop flow editing

- **Test Area:**
  - Type a test message to see which trigger matches and what reply would be sent

---

### 8. 🔗 WhatsApp Accounts
**File:** `frontend/src/lib/components/desktop-interface/whatsapp/WAAccounts.svelte`
**Window Size:** 1000×600

**Content:**
- **Connected Numbers List:**
  - Phone number, display name
  - Quality rating (🟢🟡🔴)
  - Status: Connected / Disconnected
  - Set as active/default number button

- **Connect New Number:**
  - Step-by-step guide
  - Input fields: WABA ID, Phone Number ID, Access Token
  - Test connection button
  - Save & activate

- **Disconnect** — remove a number with confirmation

- **Subscription Status:**
  - Meta API tier
  - Messages remaining
  - Billing info

---

### 9. ⚙️ WhatsApp Settings
**File:** `frontend/src/lib/components/desktop-interface/whatsapp/WASettings.svelte`
**Window Size:** 1100×650

**Tabs:**
- **Business Profile:**
  - Business name, description, address
  - Email, website
  - Profile picture upload
  - Business category

- **Phone Profile:**
  - Display name
  - About text
  - Profile photo

- **Webhook Configuration:**
  - Webhook URL
  - Verify token
  - Status indicator (active/inactive)
  - Test webhook button

- **Notifications:**
  - Toggle alerts for: new message, bot escalation, broadcast complete, template approved/rejected

- **Business Hours:**
  - Set operating hours per day
  - Auto-reply message outside hours

- **Defaults:**
  - Default reply language (AR/EN)
  - API info (Graph API version, WABA ID, Phone Number ID — read-only)

---

## 🗄️ Database Tables (New)

### `wa_accounts`
Connected WhatsApp Business accounts.
| Column | Type | Description |
|---|---|---|
| id | uuid PK | |
| phone_number | varchar(20) | E.164 format |
| display_name | text | Business display name |
| waba_id | text | WhatsApp Business Account ID |
| phone_number_id | text | Meta Phone Number ID |
| access_token | text | Encrypted access token |
| quality_rating | varchar(10) | GREEN/YELLOW/RED |
| status | varchar(20) | connected/disconnected |
| is_default | boolean | Active account flag |
| created_at | timestamptz | |
| updated_at | timestamptz | |

### `wa_conversations`
Track conversations with customers.
| Column | Type | Description |
|---|---|---|
| id | uuid PK | |
| wa_account_id | uuid FK | → wa_accounts |
| customer_id | uuid FK | → customers |
| customer_phone | varchar(20) | |
| customer_name | text | |
| last_message_at | timestamptz | Last message timestamp |
| last_message_preview | text | Preview text |
| unread_count | int | Unread messages |
| is_bot_handling | boolean | Bot currently handling? |
| bot_type | varchar(20) | 'ai' / 'auto_reply' / null |
| status | varchar(20) | active/archived |
| created_at | timestamptz | |

### `wa_messages`
All WhatsApp messages (sent & received).
| Column | Type | Description |
|---|---|---|
| id | uuid PK | |
| conversation_id | uuid FK | → wa_conversations |
| wa_account_id | uuid FK | → wa_accounts |
| whatsapp_message_id | text | Meta message ID |
| direction | varchar(10) | inbound/outbound |
| message_type | varchar(20) | text/image/document/template/button/interactive |
| content | text | Message body |
| media_url | text | Media attachment URL |
| media_mime_type | varchar(50) | |
| template_name | varchar(100) | If template message |
| template_language | varchar(10) | |
| status | varchar(20) | sent/delivered/read/failed |
| sent_by | varchar(20) | user/ai_bot/auto_reply_bot/system |
| sent_by_user_id | uuid | If sent by human user |
| error_details | text | |
| created_at | timestamptz | |

### `wa_templates`
Local cache of Meta templates.
| Column | Type | Description |
|---|---|---|
| id | uuid PK | |
| wa_account_id | uuid FK | → wa_accounts |
| meta_template_id | text | Meta's template ID |
| name | varchar(100) | Template name |
| category | varchar(20) | MARKETING/UTILITY/AUTHENTICATION |
| language | varchar(10) | en/ar |
| status | varchar(20) | APPROVED/PENDING/REJECTED |
| header_type | varchar(20) | none/text/image/video/document |
| header_content | text | Header text or media URL |
| body_text | text | Body with {{variables}} |
| footer_text | text | |
| buttons | jsonb | Button definitions |
| meta_data | jsonb | Full Meta API response |
| created_at | timestamptz | |
| updated_at | timestamptz | |

### `wa_broadcasts`
Broadcast campaigns.
| Column | Type | Description |
|---|---|---|
| id | uuid PK | |
| wa_account_id | uuid FK | → wa_accounts |
| name | text | Campaign name |
| template_id | uuid FK | → wa_templates |
| recipient_filter | varchar(20) | all/inside_24hr/outside_24hr/custom/group |
| recipient_group_id | uuid FK | → wa_contact_groups (nullable) |
| total_recipients | int | |
| sent_count | int | |
| delivered_count | int | |
| read_count | int | |
| failed_count | int | |
| status | varchar(20) | draft/sending/completed/scheduled |
| scheduled_at | timestamptz | |
| completed_at | timestamptz | |
| created_by | uuid FK | → auth.users |
| created_at | timestamptz | |

### `wa_broadcast_recipients`
Per-recipient broadcast results.
| Column | Type | Description |
|---|---|---|
| id | uuid PK | |
| broadcast_id | uuid FK | → wa_broadcasts |
| customer_id | uuid FK | → customers |
| phone_number | varchar(20) | |
| customer_name | text | |
| whatsapp_message_id | text | |
| status | varchar(20) | sent/delivered/read/failed |
| error_details | text | |
| sent_at | timestamptz | |

### `wa_contact_groups`
Saved recipient groups for broadcasts.
| Column | Type | Description |
|---|---|---|
| id | uuid PK | |
| name | text | Group name |
| description | text | |
| customer_count | int | |
| created_by | uuid FK | |
| created_at | timestamptz | |

### `wa_contact_group_members`
Members of contact groups.
| Column | Type | Description |
|---|---|---|
| id | uuid PK | |
| group_id | uuid FK | → wa_contact_groups |
| customer_id | uuid FK | → customers |
| added_at | timestamptz | |

### `wa_auto_reply_triggers`
Rule-based bot trigger definitions.
| Column | Type | Description |
|---|---|---|
| id | uuid PK | |
| wa_account_id | uuid FK | → wa_accounts |
| trigger_words_en | text[] | English trigger words |
| trigger_words_ar | text[] | Arabic trigger words |
| match_type | varchar(20) | exact/contains/starts_with |
| reply_type | varchar(20) | text/image/file/template/interactive |
| reply_text | text | |
| reply_media_url | text | |
| reply_template_id | uuid FK | → wa_templates (nullable) |
| reply_buttons | jsonb | Button definitions |
| follow_up_trigger_id | uuid FK | → self (nullable, for flows) |
| sort_order | int | Priority order |
| is_active | boolean | |
| created_at | timestamptz | |
| updated_at | timestamptz | |

### `wa_ai_bot_config`
AI bot configuration (singleton).
| Column | Type | Description |
|---|---|---|
| id | uuid PK | |
| is_enabled | boolean | Bot on/off |
| tone | varchar(20) | formal/friendly/professional |
| default_language | varchar(10) | en/ar/auto |
| max_replies_per_conversation | int | Before escalation |
| handoff_keywords | text[] | Words that trigger escalation |
| training_data | jsonb | Array of training entries |
| custom_instructions | text | |
| created_at | timestamptz | |
| updated_at | timestamptz | |

### `wa_settings`
WhatsApp settings (singleton per account).
| Column | Type | Description |
|---|---|---|
| id | uuid PK | |
| wa_account_id | uuid FK | → wa_accounts |
| business_name | text | |
| business_description | text | |
| business_address | text | |
| business_email | text | |
| business_website | text | |
| business_category | text | |
| profile_picture_url | text | |
| about_text | text | |
| webhook_url | text | |
| webhook_verify_token | text | |
| webhook_active | boolean | |
| business_hours | jsonb | Per-day hours |
| outside_hours_message | text | |
| default_language | varchar(10) | |
| notify_new_message | boolean | |
| notify_bot_escalation | boolean | |
| notify_broadcast_complete | boolean | |
| notify_template_status | boolean | |
| created_at | timestamptz | |
| updated_at | timestamptz | |

---

## 🔌 Edge Functions

### Updated: `send-whatsapp` (existing)
- Add new actions: `send_message`, `send_template`, `send_broadcast`
- Support sending: text, image, document, interactive (buttons/links)
- Support bulk sending for broadcasts

### New: `whatsapp-webhook`
- Receives incoming messages from Meta webhook
- Stores in `wa_messages` table
- Updates `wa_conversations` (last_message, unread_count)
- Triggers auto-reply bot matching
- Triggers AI bot if no auto-reply match
- Updates 24hr window status

### New: `whatsapp-ai-reply`
- Called by webhook when AI bot should respond
- Reads training data from `wa_ai_bot_config`
- Calls OpenAI API (key from env var)
- Sends reply via WhatsApp Cloud API
- Logs in `wa_messages`

### New: `whatsapp-manage`
- Manage Meta API operations:
  - Create/edit/delete templates
  - Get business profile
  - Update business profile
  - Get phone number quality
  - Sync templates from Meta

---

## 📂 File Structure

```
frontend/src/lib/components/desktop-interface/whatsapp/
├── WADashboard.svelte          (📊 Dashboard)
├── WALiveChat.svelte           (💬 Live Chat)
├── WABroadcasts.svelte         (📢 Broadcasts)
├── WATemplates.svelte          (📝 Templates)
├── WAContacts.svelte           (👥 Contacts)
├── WAaiBot.svelte              (🤖 AI Bot)
├── WAAutoReplyBot.svelte       (🔧 Auto-Reply Bot)
├── WAAccounts.svelte           (🔗 Accounts)
└── WASettings.svelte           (⚙️ Settings)

supabase/functions/
├── send-whatsapp/index.ts      (updated)
├── whatsapp-webhook/index.ts   (new)
├── whatsapp-ai-reply/index.ts  (new)
└── whatsapp-manage/index.ts    (new)
```

---

## 🔑 Environment Variables

### Vercel (frontend)
- No new frontend env vars needed (all API calls go through edge functions)

### Server Docker .env (edge functions)
- `WHATSAPP_ACCESS_TOKEN` (existing)
- `WHATSAPP_PHONE_NUMBER_ID` (existing)
- `OPENAI_API_KEY` (new — for AI bot)
- `WHATSAPP_WEBHOOK_VERIFY_TOKEN` (new — for webhook verification)

---

## 🌐 i18n Keys (nav section)

### English (`en.ts`)
```
whatsapp: "WhatsApp"
whatsappDashboard: "Dashboard"
whatsappLiveChat: "Live Chat"
whatsappBroadcasts: "Broadcasts"
whatsappTemplates: "Templates"
whatsappContacts: "Contacts"
whatsappAiBot: "AI Bot"
whatsappAutoReplyBot: "Auto-Reply Bot"
whatsappAccounts: "Accounts"
whatsappSettings: "Settings"
```

### Arabic (`ar.ts`)
```
whatsapp: "واتساب"
whatsappDashboard: "لوحة التحكم"
whatsappLiveChat: "المحادثات المباشرة"
whatsappBroadcasts: "الرسائل الجماعية"
whatsappTemplates: "القوالب"
whatsappContacts: "جهات الاتصال"
whatsappAiBot: "بوت الذكاء الاصطناعي"
whatsappAutoReplyBot: "بوت الرد التلقائي"
whatsappAccounts: "الحسابات"
whatsappSettings: "الإعدادات"
```

---

## 📋 Implementation Order

1. **Database** — Create all tables & RPCs
2. **Edge Functions** — webhook, ai-reply, manage
3. **WAAccounts.svelte** — Connect numbers first (needed by everything else)
4. **WASettings.svelte** — Configure business profile & webhook
5. **WAContacts.svelte** — View customers with 24hr status
6. **WATemplates.svelte** — Create & manage templates
7. **WALiveChat.svelte** — Chat with customers
8. **WABroadcasts.svelte** — Bulk messaging
9. **WAAutoReplyBot.svelte** — Rule-based bot
10. **WAaiBot.svelte** — AI-powered bot
11. **WADashboard.svelte** — Overview (needs data from all above)
12. **Sidebar + i18n** — Wire up navigation

---

## ✅ Approval Checklist

- [ ] 9 sidebar buttons confirmed
- [ ] Window contents confirmed
- [ ] Design style (ShiftAndDayOff) confirmed
- [ ] Database schema approved
- [ ] Edge function plan approved
- [ ] Implementation order approved
- [ ] Ready to start implementation
