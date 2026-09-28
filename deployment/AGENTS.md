# Aqura production deployment instructions

These instructions apply to every human or AI agent working in this folder.

## Standard deployment

From the repository root, run:

```powershell
.\deployment\push-and-deploy.cmd
```

The command must remain the single production deployment entry point. It verifies that the current branch is `master` and that the working tree is clean, increments all four interface version numbers, commits that version, builds the frontend locally, pushes the commit to GitHub, uploads an isolated release through SSH, activates it atomically, tests the public URL, and rolls back if the health check fails. After a healthy deployment, it retains the newest three releases and deletes older deployment files safely.

Do not manually copy frontend files, upload `.env` files, change DNS, edit Nginx, replace certificates, or restart unrelated services during a routine deployment.

## Before reporting success

Confirm all of the following:

1. All intended changes are committed.
2. The command completed without an error.
3. The version-bump commit was pushed successfully.
4. The deployment script reported a healthy public endpoint.
5. `https://urbanaqura.com/` returns HTTP 200.

## Safe validation without deployment

Run this to build and package locally without pushing or changing the server:

```powershell
.\deployment\push-and-deploy.cmd -DryRun
```

## Secrets and access

This folder contains no private credentials and must be committed to Git. The private SSH key remains outside the repository at `~/.ssh/id_ed25519_nopass`. The production runtime secrets remain on the server at `/opt/aqura-web/shared/.env`.

The version source is `frontend/src/lib/appVersion.ts`. Never edit separate interface version strings; all interfaces must import their value from that file. A dry run reports the current and next version but does not change or commit it.

Never commit or upload a private SSH key, service-role key, database password, private VAPID key, or production `.env` file.

Only a trusted computer with the authorized SSH key can perform the server deployment. GitHub does not perform the production deployment.
