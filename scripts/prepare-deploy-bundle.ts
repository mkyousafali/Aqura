import fs from 'fs';
import path from 'path';

console.log('📦 Creating frontend-only deployment bundle directory (aqura-ready-to-deploy)...');
const rootDir = process.cwd();
const bundleDir = path.join(rootDir, 'aqura-ready-to-deploy');

if (fs.existsSync(bundleDir)) {
  fs.rmSync(bundleDir, { recursive: true, force: true });
}
fs.mkdirSync(bundleDir, { recursive: true });

function copyDir(src: string, dest: string) {
  if (!fs.existsSync(src)) return;
  fs.mkdirSync(dest, { recursive: true });
  const entries = fs.readdirSync(src, { withFileTypes: true });
  for (const entry of entries) {
    const srcPath = path.join(src, entry.name);
    const destPath = path.join(dest, entry.name);
    if (entry.isDirectory()) {
      if (entry.name !== 'node_modules' && entry.name !== '.git' && entry.name !== '.svelte-kit') {
        copyDir(srcPath, destPath);
      }
    } else {
      fs.copyFileSync(srcPath, destPath);
    }
  }
}

// 1. Copy compiled frontend build
console.log('📁 Copying built frontend...');
const frontendDest = path.join(bundleDir, 'frontend');
fs.mkdirSync(frontendDest, { recursive: true });

const svelteOutput = path.join(rootDir, 'frontend', '.svelte-kit', 'output');
if (fs.existsSync(svelteOutput)) {
  copyDir(svelteOutput, path.join(frontendDest, 'build'));
}
if (fs.existsSync(path.join(rootDir, 'frontend', 'package.json'))) {
  fs.copyFileSync(path.join(rootDir, 'frontend', 'package.json'), path.join(frontendDest, 'package.json'));
}

// 2. Read original .env and keep all Google/API keys, but replace Supabase credentials with placeholders
console.log('📄 Copying original .env with Supabase placeholders...');
const envPath = path.join(rootDir, '.env');
let envContent = '';

if (fs.existsSync(envPath)) {
  envContent = fs.readFileSync(envPath, 'utf8');

  // Replace Supabase URL & Keys with placeholders
  envContent = envContent.replace(/^VITE_SUPABASE_URL=.*$/m, 'VITE_SUPABASE_URL=https://<YOUR_LOCAL_SUPABASE_URL>');
  envContent = envContent.replace(/^VITE_SUPABASE_ANON_KEY=.*$/m, 'VITE_SUPABASE_ANON_KEY=<YOUR_LOCAL_SUPABASE_ANON_KEY>');
  envContent = envContent.replace(/^VITE_SUPABASE_SERVICE_KEY=.*$/m, 'VITE_SUPABASE_SERVICE_KEY=<YOUR_LOCAL_SUPABASE_SERVICE_ROLE_KEY>');
  envContent = envContent.replace(/^DATABASE_URL=.*$/m, 'DATABASE_URL=postgres://supabase_admin:<YOUR_PASSWORD>@<YOUR_LOCAL_IP>:5432/postgres');
  envContent = envContent.replace(/^PUBLIC_SUPABASE_URL=.*$/m, 'PUBLIC_SUPABASE_URL=https://<YOUR_LOCAL_SUPABASE_URL>');
} else {
  envContent = `VITE_SUPABASE_URL=https://<YOUR_LOCAL_SUPABASE_URL>
VITE_SUPABASE_ANON_KEY=<YOUR_LOCAL_SUPABASE_ANON_KEY>
VITE_SUPABASE_SERVICE_KEY=<YOUR_LOCAL_SUPABASE_SERVICE_ROLE_KEY>
DATABASE_URL=postgres://supabase_admin:<YOUR_PASSWORD>@<YOUR_LOCAL_IP>:5432/postgres
`;
}

fs.writeFileSync(path.join(bundleDir, '.env'), envContent);
fs.writeFileSync(path.join(frontendDest, '.env'), envContent);

console.log('🎉 Frontend build package prepared!');
