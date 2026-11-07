# Login page before the Urban design

`LoginPageBeforeUrbanDesign.svelte` is an exact copy of the main login page saved on 7 November 2026, before applying the new visual design. View it locally at `/login-backup`.

SHA-256: `D5FB793F8EDACA1F8607279DFB78D4E9B5BDA6F96A5DCF8DFFD53C61FB258A51`

To restore it, run this from the Aqura repository root:

```powershell
Copy-Item -LiteralPath 'frontend/src/lib/components/login-backups/LoginPageBeforeUrbanDesign.svelte' -Destination 'frontend/src/routes/login/+page.svelte'
```

The saved page uses the existing Aqura branding data and login flows. The new stylesheet is scoped to `.urban-login`, which the saved page does not use.
