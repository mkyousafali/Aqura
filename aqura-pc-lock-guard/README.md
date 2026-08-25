# Aqura PC Lock Guard

Windows endpoint protection/monitoring for Urban Market POS/counter PCs.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│  Aqura PC Lock Guard (Electron + Windows Services)  │
├─────────────────────────────────────────────────────┤
│  Main Lock Guard Service    – enforces policies     │
│  Watchdog Service           – monitors main service │
│  Recovery Agent             – cloud health/recovery │
│  Management UI (Electron)   – admin interface       │
└─────────────────────────────────────────────────────┘
         │                          │
         ▼                          ▼
   Local SQLite DB           Aqura Supabase Cloud
   (offline events)          (heartbeat, policies,
                              remote actions)
```

## States

`Installed → Authenticated → Configured → Protected`

## Hotkey

`Ctrl+Shift+A` — opens management UI (requires Access Code + OTP)

## Development

```bash
cd aqura-pc-lock-guard
npm install
npm run dev
```

## Build

```bash
npm run build
```
