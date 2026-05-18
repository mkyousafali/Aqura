# Surprise Box — Implementation Plan

## Status Legend
- ✅ Done
- 🔄 In Progress
- ⬜ Pending

---

## Phase 1 — Database
| Task | File | Status |
|---|---|---|
| Table: surprise_box_settings | `supabase/migrations/tables/surprise_box_settings.sql` | ✅ |
| Table: surprise_box_rewards | `supabase/migrations/tables/surprise_box_rewards.sql` | ✅ |
| Table: surprise_box_plays | `supabase/migrations/tables/surprise_box_plays.sql` | ✅ |
| Table: surprise_box_vouchers | `supabase/migrations/tables/surprise_box_vouchers.sql` | ✅ |
| RPC functions | `supabase/migrations/20260517_surprise_box_rpcs.sql` | ✅ |
| Deploy to server | SSH → psql | ✅ |

## Phase 2 — Customer Page
| Task | File | Status |
|---|---|---|
| QR scan page `/surprise-box` | `frontend/src/routes/surprise-box/+page.svelte` | ✅ |

## Phase 3 — Admin Panel
| Task | File | Status |
|---|---|---|
| SurpriseBoxManager.svelte | `frontend/src/lib/components/desktop-interface/marketing/surprise-box/SurpriseBoxManager.svelte` | ✅ |
| Sidebar: import + button + i18n | `Sidebar.svelte`, `en.ts`, `ar.ts` | ✅ |

## Phase 4 — Cashier
| Task | File | Status |
|---|---|---|
| SurpriseBoxRedemption.svelte | `frontend/src/lib/components/cashier-interface/SurpriseBoxRedemption.svelte` | ✅ |
| RedemptionWindow: new tab | `frontend/src/lib/components/cashier-interface/RedemptionWindow.svelte` | ✅ |

## Phase 5 — DB button registration
| Task | Status |
|---|---|
| Insert SURPRISE_BOX_MANAGER into sidebar_buttons | ✅ |
| Insert SURPRISE_BOX_REDEMPTION into sidebar_buttons | ✅ |

---

## File Structure
```
frontend/src/
├── routes/surprise-box/+page.svelte
├── lib/components/
│   ├── desktop-interface/marketing/surprise-box/
│   │   └── SurpriseBoxManager.svelte
│   └── cashier-interface/
│       └── SurpriseBoxRedemption.svelte
supabase/migrations/
├── tables/
│   ├── surprise_box_settings.sql
│   ├── surprise_box_rewards.sql
│   ├── surprise_box_plays.sql
│   └── surprise_box_vouchers.sql
└── 20260517_surprise_box_rpcs.sql
```

---

## RPC Summary
| Function | Purpose |
|---|---|
| `surprise_box_check_status()` | Returns active/inactive + reason |
| `surprise_box_validate_bill(bill_number, bill_amount, bill_date)` | Pre-validates bill before play |
| `surprise_box_play(...)` | Core play — server-side weighted reward, concurrency-safe |
| `surprise_box_validate_voucher(code)` | Cashier validates a voucher code |
| `surprise_box_redeem_voucher(code, bill_number, amount)` | Marks voucher redeemed |
| `surprise_box_dashboard_stats(from, to)` | Admin dashboard aggregations |

---

## Color Palette (Customer Page)
- Background: Deep purple `#3B0764` → `#6B21A8`
- Accent: Gold `#F59E0B`
- Boxes: Purple `#7C3AED` with gold ribbon
- Win: Green confetti + gold voucher card
- No-win: Grey muted card

---

## Voucher Code Format
- 12 uppercase hex chars: e.g. `SB7F3A2C91B4E`
- Generated server-side via `upper(encode(gen_random_bytes(6), 'hex'))`
- QR code: client-side via `qrcode` npm package

---

## Reward Presets (seed data)
| Label EN | Label AR | Value | Weight |
|---|---|---|---|
| 5 SAR Voucher | قسيمة 5 ريال | 5 | 30 |
| 10 SAR Voucher | قسيمة 10 ريال | 10 | 25 |
| 25 SAR Voucher | قسيمة 25 ريال | 25 | 15 |
| 50 SAR Voucher | قسيمة 50 ريال | 50 | 8 |
| 100 SAR Voucher | قسيمة 100 ريال | 100 | 2 |
| Better Luck! | حظ أوفر! | 0 (no_win) | 20 |
