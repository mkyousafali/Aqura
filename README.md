# Aqura Management System

**Version:** 2.0.2  
**Status:** Production Ready  
**Last Updated:** December 1, 2025

## 🌊 Overview

Aqura is a modern, PWA-first windowed management platform designed specifically for Saudi Arabian businesses. Built with cutting-edge technologies, it provides a comprehensive solution for managing HR, finances, customer operations, and business processes with full bilingual support (Arabic/English) and real-time synchronization capabilities.

## ✨ Key Features

### 🖥️ **Windowed Desktop-Like Interface**
- Native OS-style window management
- Drag, resize, minimize, and maximize windows
- Taskbar with application shortcuts
- Command palette (Ctrl+Shift+P) for quick actions

### 📱 **Progressive Web App (PWA)**
- Installable on desktop and mobile devices
- Offline-first architecture with background sync
- Push notifications support
- Advanced caching strategies
- Service worker with custom offline handling

### 🌐 **Bilingual Support**
- Arabic and English localization
- RTL (Right-to-Left) layout support
- Contextual language switching
- Cultural adaptation for Saudi market

### 🏢 **Business Management Modules**
- **HR Management**: Employee records, departments, positions, salary, biometric attendance
- **Branch Management**: Multi-location operations across Saudi Arabia
- **Vendor Management**: Supplier relationships, payment schedules, visit tracking
- **Receiving Management**: Receiving workflow with task assignments and completion tracking
- **Task Management**: Assignment system with reminders, completion tracking, and quick tasks
- **Finance Management**: Expense requisitions, payments, employee warnings/fines
- **Customer Management**: Mobile app for customers with order placement and tracking
- **Product & Offers**: Product catalog, variation groups, offer management, coupon system
- **Notification System**: Push notifications with attachments and real-time updates
- **User Management**: Role-based access control with function-level permissions

### ♿ **Accessibility**
- WCAG 2.1 compliant
- Screen reader support
- Keyboard navigation
- High contrast mode
- ARIA labels and descriptions

### 🔒 **Security & Data**
- Supabase backend with Row Level Security (RLS)
- JWT authentication
- Encrypted data transmission
- GDPR/PDPA compliance ready

## 🛠️ Tech Stack

### Frontend
- **SvelteKit** - Modern web framework
- **TypeScript** - Type-safe development
- **TailwindCSS** - Utility-first styling
- **Vite PWA** - Progressive Web App features
- **Workbox** - Advanced service worker

### Backend
- **Supabase** - Backend-as-a-Service (PostgreSQL + Auth + Storage + Realtime)
- **PostgreSQL** - Primary database with 65+ tables
- **Row Level Security (RLS)** - Database-level security policies
- **Edge Functions** - Serverless functions for push notifications
- **ERP Integration** - Real-time sync with URBAN2_2025 ERP system
- **Biometric Integration** - ZKBioTime attendance sync

### DevOps & Tools
- **pnpm** - Fast package manager (monorepo workspace)
- **Vercel** - Frontend deployment platform
- **Git** - Version control (GitHub repository)
- **VS Code** - Primary development environment
- **PowerShell** - Windows development shell

## 🚀 Quick Start

### Prerequisites
- Node.js 18+ with npm/pnpm
- Supabase account (project already configured)
- VS Code (recommended)
- Windows PowerShell

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/mkyousafali/Aqura.git
   cd Aqura
   ```

2. **Install dependencies**
   ```bash
   cd frontend
   npm install
   ```

3. **Configure environment variables**
   ```bash
   # Create .env file in frontend/ directory
   cp .env.example .env
   # Add Supabase credentials (already configured)
   ```

4. **Start development server**
   
   **Using VS Code Tasks (Recommended):**
   - Press `Ctrl+Shift+B`
   - Select **"🎨 Dev Frontend (npm)"**
   - Server starts on http://localhost:5173
   
   **Using Terminal:**
   ```bash
   cd frontend
   npm run dev
   ```

5. **Open the application**
   - Desktop Interface: http://localhost:5173/desktop-interface
   - Mobile Interface: http://localhost:5173/mobile-interface
   - Customer App: http://localhost:5173/customer-interface
   - Cashier Interface: http://localhost:5173/cashier-interface

## 📱 Features Implemented

### ✅ **Desktop Admin Interface** (36+ Components)
- **Window Management**: Drag, resize, minimize, maximize windows with taskbar
- **Sidebar Navigation**: Multi-level menus with role-based access control
- **Command Palette**: Quick actions (Ctrl+Shift+P)
- **Master Data Management**: 
  - HR (Employees, Departments, Positions)
  - Branches, Vendors, Tasks
  - Products, Categories, Units, Tax Categories
- **Work Management**:
  - Receiving workflow with task assignments
  - Quick tasks with assignments and comments
  - Task completion tracking
- **Financial Management**:
  - Expense requisitions and approvals
  - Payment tracking and scheduler
  - Employee warnings and fine payments
- **Customer App Management**:
  - Product management with variations
  - Offer management (Product, Bundle, BOGO, Cart Tiers)
  - Coupon system with redemption tracking
  - Delivery settings and fee tiers
- **Communication**: 
  - Notification center with attachments
  - Push notification management
- **Settings**: User management, permissions, app functions

### ✅ **Mobile Employee Interface** (4 Components)
- **My Tasks**: Personal task dashboard with completion tracking
- **Notifications**: Real-time notification center
- **Biometric Display**: Check-in/check-out history with timezone conversion
- **Language Toggle**: Switch between Arabic and English

### ✅ **Customer Shopping App** (7 Components)
- **Product Browsing**: Featured offers and product catalog
- **Shopping Cart**: Bottom cart bar with real-time updates
- **Offer System**: View and apply multiple offer types
- **Customer Login/Registration**: Mobile number-based authentication
- **Account Recovery**: Access code recovery system

### ✅ **Cashier/POS Interface** (4 Components)
- **Standalone Desktop Interface**: Dedicated cashier environment
- **Coupon Redemption**: Validate and redeem customer coupons
- **Access Code Authentication**: Secure cashier login
- **Cashier Taskbar**: Simplified navigation for POS operations

### ✅ **Database & Backend** (Supabase)
- **65 Tables**: Complete database schema with RLS policies
- **256 Functions**: Database functions for business logic
- **71 Triggers**: Auto-calculations, synchronization, audit logging
- **Real-time Sync**: Live updates across all interfaces
- **ERP Integration**: Sync with URBAN2_2025 ERP system
- **Biometric Integration**: ZKBioTime attendance synchronization

### ✅ **Internationalization (i18n)**
- Custom bilingual system (Arabic RTL + English LTR)
- Domain-specific translations (not auto-translate)
- Cultural adaptations for Saudi market
- Font system: Noto Sans Arabic + Inter
- Localized dates, numbers, currency

### ✅ **PWA Features**
- Installable on desktop and mobile
- Service worker with offline support
- Push notifications with FCM integration
- Background sync capabilities
- Update prompts and version management

### ✅ **Security & Permissions**
- Supabase Authentication with JWT
- Row Level Security (RLS) policies on all tables
- Function-level permissions system
- Role-based access control (Master Admin, Admin, Users)
- Audit trails for all operations

## 📁 Project Structure

```
Aqura/
├── frontend/                           # SvelteKit PWA frontend
│   ├── src/
│   │   ├── lib/
│   │   │   ├── components/             # UI components (organized by interface)
│   │   │   │   ├── common/             # Shared components
│   │   │   │   ├── desktop-interface/  # Desktop admin components (36+)
│   │   │   │   ├── customer-interface/ # Customer app components (7)
│   │   │   │   ├── mobile-interface/   # Mobile employee components (4)
│   │   │   │   └── cashier-interface/  # Cashier/POS components (4)
│   │   │   ├── stores/                 # Svelte stores (windowManager, notifications, auth)
│   │   │   ├── utils/                  # Utility functions and helpers
│   │   │   ├── types/                  # TypeScript type definitions
│   │   │   └── i18n/                   # Custom bilingual system (en.ts, ar.ts)
│   │   ├── routes/                     # SvelteKit file-based routing
│   │   │   ├── desktop-interface/      # Desktop admin routes
│   │   │   ├── customer-interface/     # Customer app routes
│   │   │   ├── mobile-interface/       # Mobile employee routes
│   │   │   ├── cashier-interface/      # Cashier/POS routes
│   │   │   └── api/                    # API endpoints (+server.js)
│   │   ├── app.html                    # HTML template
│   │   └── app.css                     # Global styles
│   ├── static/                         # Static assets (icons, sounds, manifest)
│   ├── vite.config.ts                  # Vite + PWA configuration
│   └── package.json
├── supabase/                           # Supabase backend configuration
│   ├── functions/                      # Edge functions (push notifications)
│   └── config.toml                     # Supabase configuration
├── scripts/                            # Utility scripts
│   ├── update-version.js               # Version management
│   ├── check-employee-punches.js       # Biometric data verification
│   └── add-missing-functions.js        # Database function setup
├── Do not delete/                      # Documentation and guides
│   ├── .copilot-instructions.md        # AI assistant instructions
│   ├── VERSION_MANAGEMENT.md           # Version update process
│   ├── COUPON_MANAGEMENT_SYSTEM_PLAN.md
│   ├── ORDER_SYSTEM_IMPLEMENTATION_PLAN.md
│   ├── BIOMETRIC_SYNC_IMPLEMENTATION_PLAN.md
│   └── [other documentation files]
├── build/                              # Production build output
├── package.json                        # Root workspace configuration
├── pnpm-workspace.yaml                 # pnpm monorepo configuration
└── README.md                           # This file
```

## 🛠️ Development Setup

### Prerequisites

- Node.js 18+ and PNPM
- Go 1.21+
- Docker and Docker Compose

### Quick Start

1. **Clone and install dependencies**:
   ```bash
   git clone <repository-url>
   cd aqura
   pnpm setup
   ```

2. **Environment setup**:
   ```bash
   cp .env.example .env
   # Edit .env with your Supabase credentials
   ```

3. **Start development environment**:
   ```bash
   pnpm dev
   # or with Docker
   pnpm docker:dev
   ```

4. **Access the application**:
   - Frontend: http://localhost:5173
   - Backend API: http://localhost:8080

## 🌐 Internationalization (i18n)

Aqura features a custom-built i18n system designed specifically for the domain (not generic auto-translation):

### Features
- **Arabic (RTL)** and **English (LTR)** support
- Domain-specific translations for business terminology
- Pluralization rules per language
- Date/number/currency localization
- RTL/LTR layout switching with mirrored icons
- Locale-aware fonts (Noto Sans Arabic + Inter)

### Usage
```typescript
import { t, switchLocale, isRTL } from '$i18n';

// Get translation
const title = t('admin.hrMaster'); // "HR Master" / "إدارة الموارد البشرية"

// Switch language
switchLocale('ar'); // Changes entire UI to Arabic RTL

// Check if current locale is RTL
if (isRTL()) {
  // Apply RTL-specific logic
}
```

## 📱 PWA Features

- **App Manifest**: Configures installation behavior and metadata
- **Service Worker**: Handles caching, offline support, and updates
- **Background Sync**: Retries failed operations when back online
- **Update Notifications**: Prompts users when new versions are available
- **Responsive**: Touch and keyboard parity across devices

## 🪟 Windows Installer

Post-development, the PWA can be packaged as a Windows desktop application:

- **Electron Builder**: Wraps PWA in desktop container
- **Auto-Update**: Seamless update delivery system
- **Signed Builds**: Code signing for trusted installation
- **Native Integration**: System tray, file associations, etc.

## 🔐 Authentication & Security

### User Authentication
- **Desktop/Mobile**: Supabase Auth with username/password
- **Customer App**: Mobile number-based with access codes
- **Cashier Interface**: Access code authentication
- **Session Management**: JWT tokens with automatic refresh

### Security Features
- **Row Level Security (RLS)**: Database-level access control on all tables
- **Function Permissions**: Granular permissions (view, add, edit, delete, export)
- **Role-based Access**: Master Admin, Admin, and custom user roles
- **Audit Trails**: Complete logging of user actions
- **Password History**: Prevents password reuse
- **Device Sessions**: Track and manage user devices

## 📊 Key System Components

### Desktop Admin Modules
1. **HR Management**: Employees (203), departments, positions, salary components
2. **Branch Management**: 3 branches across Saudi Arabia
3. **Vendor Management**: Supplier details, payment schedules, visit tracking
4. **Receiving Management**: 755 receiving records with workflow automation
5. **Task Management**: Assignment system with reminders and completion tracking
6. **Finance Management**: Expense requisitions, payments, warnings/fines
7. **Product Management**: Catalog with variations, categories, units, tax
8. **Offer Management**: Product offers, bundles, BOGO, cart tiers
9. **Coupon System**: Campaign-based redemption with stock control
10. **Customer Management**: Registration, recovery, app media
11. **Notification System**: Push notifications with attachments
12. **User Management**: 49 users with role-based permissions

### External Integrations
- **ERP Sync**: Real-time synchronization with URBAN2_2025 (267 tables)
  - Sales data sync (1.4M+ transaction details)
  - Product catalog sync (67,898 products)
  - Inventory updates
- **Biometric Sync**: ZKBioTime attendance integration (142 tables)
  - Employee punch records
  - Device management
  - Attendance reporting

## 🧪 Testing & Quality

- **ESLint + Prettier**: Code formatting and linting
- **TypeScript**: Balanced typing (strict for domain, relaxed for UI)
- **Vitest**: Unit and integration testing
- **E2E Testing**: Planned with Playwright
- **Performance**: Lazy loading, code splitting, virtualization

## 🚀 Deployment

### Current Setup
- **Frontend**: Vercel (automatic deployment from GitHub)
- **Backend**: Supabase (hosted PostgreSQL + Edge Functions)
- **Domain**: Configured with custom domain (if applicable)
- **Version Control**: GitHub repository (mkyousafali/Aqura)

### Version Management
- Automated version update script (`npm run version:patch|minor|major`)
- Version displayed in both desktop and mobile interfaces
- Version popup with release notes in desktop sidebar
- Update process documented in `Do not delete/VERSION_MANAGEMENT.md`

### Deployment Process
1. Update version: `npm run version:patch`
2. Update version popup content in Sidebar.svelte
3. Commit changes: `git add -A && git commit -m "feat: description"`
4. Push to GitHub: `git push origin master`
5. Vercel auto-deploys from master branch

## 📖 Documentation

Documentation is located in the `Do not delete/` folder:

- **`.copilot-instructions.md`**: Complete system instructions for AI assistants
- **`VERSION_MANAGEMENT.md`**: Version update process and guidelines
- **`COUPON_MANAGEMENT_SYSTEM_PLAN.md`**: Coupon system implementation
- **`ORDER_SYSTEM_IMPLEMENTATION_PLAN.md`**: Order management system
- **`BIOMETRIC_SYNC_IMPLEMENTATION_PLAN.md`**: Biometric integration guide
- **`PERMISSION_SYSTEM_IMPLEMENTATION_CHECKLIST.md`**: Permission system setup
- **`PRIVILEGE_CARD_SYSTEM.md`**: ERP privilege card integration
- **`PUSH_NOTIFICATION_SYSTEM.md`**: Push notification setup and troubleshooting
- **`ADD_NEW_FUNCTION_GUIDE.md`**: Guide for adding new features
- **Additional guides**: ERP setup, ZKBioTime integration, language localization

## 🎯 System Status

### ✅ Completed Features
- [x] PWA installable on desktop and mobile
- [x] Bilingual system with RTL/LTR support (Arabic/English)
- [x] Custom i18n library with domain-specific translations
- [x] Windowed desktop interface with drag/resize/minimize
- [x] Desktop admin interface (36+ components)
- [x] Mobile employee interface (4 components)
- [x] Customer shopping app (7 components)
- [x] Cashier/POS interface (4 components)
- [x] Complete database schema (65 tables, 256 functions, 71 triggers)
- [x] Role-based access control with function permissions
- [x] Push notification system with FCM integration
- [x] Service worker with offline support
- [x] Real-time data synchronization
- [x] ERP integration with URBAN2_2025
- [x] Biometric attendance integration with ZKBioTime
- [x] Task management with assignments and reminders
- [x] Financial management (expenses, payments, warnings/fines)
- [x] Product and offer management
- [x] Coupon redemption system
- [x] Version management system

### 🚧 In Progress / Planned
- [ ] Order management system (full implementation)
- [ ] Advanced reporting and analytics
- [ ] Excel import/export for all modules
- [ ] Windows desktop installer (Electron packaging)
- [ ] Enhanced offline capabilities
- [ ] Mobile app native builds (iOS/Android)

## 📄 License

Proprietary - Aqura Management System

## 🤝 Contributing

This is a proprietary project. For contributions or questions, contact the development team.

## 📞 Support

For technical support or questions:
- Check documentation in `Do not delete/` folder
- Review `.copilot-instructions.md` for system architecture
- Contact system administrators

---

**Current Status**: ✅ Production Ready - Version 2.0.2  
**Last Updated**: December 1, 2025  
**Repository**: [github.com/mkyousafali/Aqura](https://github.com/mkyousafali/Aqura)
#   D e p l o y m e n t   t e s t   a t   0 3 / 0 3 / 2 0 2 6   0 0 : 3 1 : 4 0  
 