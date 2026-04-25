# AI Marketing Feature – Final Specification Document

for Aqura Desktop Interface

---

# 1. Project Overview

Build a new desktop feature inside Urban Market that allows users to create **AI-generated marketing content** using Google APIs.

The system will generate:

* Product promotional videos
* Product promotional posters
* Branding videos (no products)
* Branding posters (no products)

The feature must be fast, organized, brand-controlled, and easy for staff to use.

---

# 2. App Location

**Desktop Interface**

Sidebar Menu:

**Promo → Manage → AI Marketing**

Open as separate desktop window/component.

UI style must match:

**ShiftAndDayOff.svelte**

---

# 3. Main Window Sections

Top navigation buttons in one row:

1. Dashboard
2. Settings
3. Brand Libraries
4. Create Video
5. Create Poster
6. Branding Videos
7. Branding Posters
8. Library

---

# 4. Dashboard

Default first screen when opening module.

## Quick Action Buttons

* Create Video
* Create Poster
* Branding Video
* Branding Poster
* Open Library
* Settings

## Stats Cards (Recommended)

* Videos created today
* Posters created today
* This month creations
* API cost today
* API cost this month
* Most used products
* Last generated item

---

# 5. Settings

Accessible to all users with module permission.

## Global Settings

### Google API

* API Key input
* Connection test button

### Generation Defaults

* Auto Retry ON/OFF
* Speed Mode Default:

  * Fast
  * Quality
* Default Duration
* Default Platform
* Default Language

### AI Agent Base Instructions

Permanent training field.

Examples:

* Brand tone
* Offer wording style
* Marketing language style
* Output behavior rules

### Clarification Rule

AI must:

* Ask only if needed
* Ask one question at a time
* Ask fewest questions possible
* Maximum 10 questions per generation (including edits)
* If enough info exists → generate immediately

---

# 6. Brand Libraries

This replaces branch branding.

Users can create unlimited brand setups.

## Each Brand Library Contains:

### Assets

* Default Logo
* Default Character Set
* Default Colors

### Character Library

Upload multiple characters:

* Dad
* Mom
* Boy
* Girl
* Infant
* Grandfather
* Grandmother
* Any custom names

Use one / many / full family during creation.

### Fixed Branding Rules

Users cannot change logo/colors/characters during creation.

To change branding:

Edit Brand Library first.

## Actions

All users:

* Create
* Edit
* Copy
* Favorite
* Set Default
* Archive

Master Admin only:

* Delete

## Delete Rule

If linked creations exist:

Cannot delete.

Show warning:

“This brand library is linked to X creations.”

Buttons:

* View linked items
* Archive instead
* Cancel

---

# 7. Brand Library Selection

When module opens:

User selects Brand Library.

Use that brand for all actions until changed.

Per user:

* Default brand can be saved
* Favorite brands supported

---

# 8. Product Source

Use shared **`products`** table for all users.

---

# 9. Create Video

## Product Selection

* Show product table
* Select max 3 products

## Modes

Selectable:

* Single product ad
* Multi-product ad
* Combined ad

## Input Form

* Before price (manual)
* Offer price (manual)
* Additional requirements
* Language
* Platform
* Duration
* Font mode
* Music mode
* Speed mode

## Language

Multiple languages supported.

Only selected language used.

## Platforms

* WhatsApp
* Instagram
* TikTok
* Snapchat
* Facebook

## Aspect Ratio

User selects:

* Vertical
* Square
* Landscape

## Duration

* 10 sec
* 15 sec
* 20 sec
* 30 sec

## Character

Uses selected Brand Library characters.

## Font

Two modes:

* User choose from `fonts` table
* AI auto choose best font based on language/style

## Music

Two modes:

* User choose uploaded track
* AI auto choose best track

## Output

Video includes:

* Products
* Offer prices
* Character speaking
* Logo
* Brand colors
* Text overlays
* Music
* Platform fit size

---

# 10. Branding Videos

No product required.

Use:

* Logo
* Characters
* Marketing message

Modes:

* AI generate message
* User custom message
* Both selectable

Templates + free custom prompt.

Examples:

* Grand Opening
* Brand Awareness
* Delivery Service
* Ramadan
* Thank You Customers

---

# 11. Create Poster

Same flow as Create Video.

Supports:

* Single product
* Multi-product
* Combined product ad
* Family/character style

---

# 12. Branding Posters

Same as Branding Videos, but poster output.

---

# 13. Poster Download Modes

## Social Media

* Instagram Post
* Instagram Story
* Facebook
* WhatsApp Status
* Snapchat
* TikTok Cover

## Print

* A5
* A4
* A3
* Custom Size

---

# 14. AI Clarification Workflow

Before generation:

### If info complete:

Generate immediately.

### If info missing:

Ask one question at a time.

Rules:

* Fewest questions possible
* Max 10 questions
* Applies to edits too

---

# 15. Text Draft Workflow

Before final rendering:

1. AI creates draft script/text
2. Auto-correct spelling
3. Auto-correct grammar
4. Improve wording
5. Show user preview text
6. User edits if needed
7. Final generation starts

---

# 16. Edit / Regenerate

After creation:

* Show preview
* Text box for edits
* Unlimited regenerate attempts

---

# 17. Download

Available after first generation.

No watermark.

---

# 18. Save to Database

Nothing auto-saves.

Manual button:

**Save to Database**

Store full file binary inside database.

For each item save:

* File
* Type
* Brand Library
* Products
* Prices
* Platform
* Duration
* Language
* Prompt
* Edit history
* User
* Date/time

---

# 19. Shared Library

Visible to all users with access.

## Features

* Thumbnail preview
* Quick download
* Duplicate item
* Edit again
* Rename
* Move folders
* Search
* Filters

## Filters

* Date
* Product
* Brand Library
* Type
* Language
* Platform

## Version History

Keep old versions.

## Delete

Master Admin only.

---

# 20. Queue System

Background generation supported.

Users continue using app.

## Per User Queue

Each user controls own jobs.

## All Users Can View All Queues

## Queue Controls

* Reorder own jobs
* Pause own jobs
* Cancel own jobs
* Duplicate own jobs

## Processing Limit

1 running job at a time.

---

# 21. Notifications

Use:

* Toast popup
* Notification history panel

For:

* Started
* Progress
* Completed
* Failed
* Saved

---

# 22. Permissions

Single button permission to open module.

If user has access:

Full use of module.

Exceptions:

### Master Admin Only

* Delete saved items
* Delete Brand Libraries

---

# 23. Storage / Logs

Minimal logs only.

No heavy audit system.

---

# 24. Recommended Database Tables

## ai_brand_libraries

## ai_brand_characters

## ai_marketing_files

## ai_marketing_versions

## ai_generation_queue

## ai_music_library

## ai_notifications

---

# 25. Recommended Implementation Phases

## Phase 1 (Launch)

* Dashboard
* Settings
* Brand Libraries
* Poster Generator
* Video Generator
* Branding Posts
* Queue
* Shared Library
* Google standard voices

## Phase 2

* Auto social posting
* Advanced analytics
* Better AI voice cloning
* Campaign scheduling

---

# 26. Recommended Google APIs

* Gemini (text/script)
* Veo (video)
* Imagen (poster/image if available)
* Google Text-to-Speech

---

# 27. Final Feasibility

## Fully Implementable: YES

## Complexity Level:

Medium to High

## Recommended Build Order:

1. Brand Libraries
2. Poster Generator
3. Shared Library
4. Video Generator
5. Queue System
6. Dashboard polish

---

# 28. Final Developer Note

Build modularly so future features can plug in easily.

This feature can become a major marketing engine 
