# Aqura Management System

<!-- Updated for Vercel deployment test -->

## 🌊 Overview

Aqura is a modern, PWA-first windowed management platform designed specifically for Saudi Arabian businesses. Built with cutting-edge technologies, it provides a comprehensive solution for managing employees, branches, vendors, and business operations with full bilingual support (Arabic/English) and advanced offline capabilities.

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
- **HR Management**: Employee records, departments, payroll
- **Branch Management**: Multi-location operations, regional management
- **Vendor Management**: Supplier relationships, purchase orders
- **User Management**: Role-based access control

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
- **Go (Golang)** - High-performance server
- **Fiber** - Fast HTTP framework
- **GORM** - Database ORM
- **PostgreSQL** - Primary database
- **Supabase** - BaaS for rapid development

### DevOps & Tools
- **pnpm** - Fast package manager
- **Monorepo** - Organized codebase
- **ESLint/Prettier** - Code quality
- **Docker** - Containerization

## 🚀 Quick Start

### Prerequisites
- Node.js 18+ with pnpm
- Go 1.21+
- Docker (optional)
- Supabase account (for production)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-org/aqura.git
   cd aqura
   ```

2. **Install dependencies**
   ```bash
   pnpm install
   ```

3. **Start development servers**
   ```bash
   # Terminal 1: Frontend
   cd frontend && npm run dev
   
   # Terminal 2: Backend
   cd backend && go run cmd/server/main.go
   ```

4. **Open the application**
   - Frontend: http://localhost:5173
   - Backend API: http://localhost:8080

## 📱 Features Implemented

### ✅ **Core Infrastructure**
- Monorepo structure with pnpm workspaces
- SvelteKit with TypeScript and TailwindCSS
- Go backend with clean architecture
- Comprehensive PWA configuration

### ✅ **UI/UX Components**
- Desktop-style windowed interface
- Window Manager with drag/resize/minimize
- Taskbar with application shortcuts
- Command Palette for quick actions
- Responsive design system

### ✅ **Business Modules**
- **HR Master**: Complete employee management
- **Branch Master**: Multi-location management  
- **Vendor Master**: Supplier relationship management
- CRUD operations with mock data

### ✅ **Internationalization**
- Arabic and English localization
- RTL layout support
- Cultural adaptations
- Dynamic language switching

### ✅ **PWA Features**
- Advanced service worker
- Offline-first architecture
- Background sync capabilities
- Installation prompts
- Custom offline pages

### ✅ **Accessibility**
- WCAG 2.1 compliance
- Screen reader support
- Keyboard navigation
- ARIA labels and descriptions

### ✅ **Data Layer**
- Supabase integration setup
- Offline data management
- Background sync queuing
- Mock data service

## 📁 Project Structure

```
aqura/
├── frontend/                 # SvelteKit PWA frontend
│   ├── src/
│   │   ├── lib/
│   │   │   ├── components/   # Reusable UI components
│   │   │   ├── stores/       # Svelte stores for state management
│   │   │   ├── utils/        # Utility functions
│   │   │   ├── types/        # TypeScript type definitions
│   │   │   └── i18n/         # Custom bilingual system
│   │   ├── routes/           # SvelteKit file-based routing
│   │   └── app.html          # HTML template
│   ├── static/              # Static assets (icons, images)
│   ├── vite.config.ts       # Vite + PWA configuration
│   └── package.json
├── backend/                 # Go Fiber backend
│   ├── cmd/server/          # Application entry point
│   ├── internal/            # Internal packages
│   │   ├── transport/       # HTTP handlers/routes
│   │   ├── service/         # Business logic
│   │   ├── repository/      # Data access layer
│   │   └── domain/          # Domain models
│   ├── pkg/                 # Public packages
│   └── go.mod
├── .vscode/                 # VS Code workspace configuration
├── docker-compose.dev.yml   # Development environment
├── package.json             # Root workspace configuration
└── README.md
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

### Bootstrap Admin
- **Username**: `masteradmin`
- **Password**: `Aquraadmin` (stored in env, not source)
- **First Login**: Forces password change + MFA setup
- **Auto-Disable**: Bootstrap account disabled after owner admin created

### Security Features
- Rate limiting and account lockout
- Multi-factor authentication (MFA)
- Row-level security (RLS) with Supabase
- Audit trail for all admin actions
- Secure session management

## 📊 Admin Modules

Each module supports both manual CRUD operations and Excel import:

1. **HR Master**: Employee management with departments and roles
2. **Branches Master**: Branch/location management
3. **Vendors Master**: Vendor and supplier management  
4. **Invoice Master**: Invoice processing and tracking
5. **User Roles**: Permission and access control management
6. **Hierarchy Master**: Organizational structure
7. **User Management**: User creation and administration

### Import Flow
1. **Upload**: Select and upload Excel (.xlsx) files
2. **Mapping**: Map Excel columns to database fields
3. **Validation**: Real-time validation with error reporting
4. **Staging**: Preview changes before committing
5. **Commit**: Apply valid changes, keep invalid for retry
6. **Audit**: Full audit trail with per-row status

## 🧪 Testing & Quality

- **ESLint + Prettier**: Code formatting and linting
- **TypeScript**: Balanced typing (strict for domain, relaxed for UI)
- **Vitest**: Unit and integration testing
- **E2E Testing**: Planned with Playwright
- **Performance**: Lazy loading, code splitting, virtualization

## 🚀 Deployment

- **Development**: Docker Compose with hot reload
- **Production**: Docker containers with nginx
- **CI/CD**: GitHub Actions pipeline
- **Monitoring**: Error tracking and performance monitoring

## 📖 Documentation Roadmap

- [ ] API Documentation
- [ ] Component Library Storybook
- [ ] User Guide (Admin & End User)
- [ ] i18n Content Authoring Guide
- [ ] Windows Packaging Guide
- [ ] Deployment Guide

## 🎯 Acceptance Criteria Status

- [x] PWA installable on browsers
- [x] Bilingual system with RTL/LTR support
- [x] Custom i18n library (no auto-translate)
- [x] Brand colors applied consistently
- [ ] Windowed UI with MDI functionality
- [ ] Bootstrap admin with forced password change
- [ ] Excel import system with audit trail
- [ ] Windows installer build
- [ ] Offline support and service worker
- [ ] Admin modules with CRUD operations

## 📄 License

Proprietary - Aqura Management System

---

**Current Status**: 🚧 In Development - Frontend foundation with i18n system completed
