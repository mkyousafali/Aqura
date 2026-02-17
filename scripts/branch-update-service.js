#!/usr/bin/env node
/**
 * Aqura Branch Frontend Update Service
 * 
 * Runs on the branch VM (port 3002) and handles:
 * - GET  /status   → Returns current version, uptime, service status
 * - POST /update   → Downloads a build ZIP from cloud, extracts, restarts frontend
 * - GET  /health   → Simple health check
 * 
 * The update process:
 * 1. Downloads ZIP from the provided cloud storage URL
 * 2. Extracts to a temp directory
 * 3. Stops the aqura-frontend systemd service
 * 4. Replaces /opt/aqura/build/ with the new files
 * 5. Starts the aqura-frontend systemd service
 * 6. Returns success/failure
 */

const http = require('http');
const https = require('https');
const fs = require('fs');
const path = require('path');
const { execSync, exec } = require('child_process');
const { pipeline } = require('stream/promises');

const PORT = 3002;
const BUILD_DIR = '/opt/aqura/build';
const TEMP_DIR = '/tmp/aqura-update';
const VERSION_FILE = path.join(BUILD_DIR, '.aqura-version.json');

// Track service start time
const startTime = Date.now();

function getVersionInfo() {
    try {
        if (fs.existsSync(VERSION_FILE)) {
            return JSON.parse(fs.readFileSync(VERSION_FILE, 'utf8'));
        }
    } catch (e) { /* ignore */ }
    return { version: 'unknown', updated_at: null, build_id: null };
}

function saveVersionInfo(version, buildId) {
    const info = {
        version,
        build_id: buildId,
        updated_at: new Date().toISOString()
    };
    fs.writeFileSync(VERSION_FILE, JSON.stringify(info, null, 2));
}

function getFrontendStatus() {
    try {
        const result = execSync('systemctl is-active aqura-frontend 2>/dev/null', { encoding: 'utf8' }).trim();
        return result;
    } catch (e) {
        return 'inactive';
    }
}

function downloadFile(url) {
    return new Promise((resolve, reject) => {
        const file = path.join(TEMP_DIR, 'frontend-build.zip');
        
        // Ensure temp dir exists
        if (fs.existsSync(TEMP_DIR)) {
            execSync(`rm -rf ${TEMP_DIR}`);
        }
        fs.mkdirSync(TEMP_DIR, { recursive: true });

        const proto = url.startsWith('https') ? https : http;
        
        const doRequest = (requestUrl, redirectCount = 0) => {
            if (redirectCount > 5) {
                reject(new Error('Too many redirects'));
                return;
            }
            
            proto.get(requestUrl, { timeout: 120000 }, (response) => {
                // Handle redirects
                if (response.statusCode >= 300 && response.statusCode < 400 && response.headers.location) {
                    doRequest(response.headers.location, redirectCount + 1);
                    return;
                }
                
                if (response.statusCode !== 200) {
                    reject(new Error(`Download failed: HTTP ${response.statusCode}`));
                    return;
                }

                const writeStream = fs.createWriteStream(file);
                response.pipe(writeStream);
                
                writeStream.on('finish', () => {
                    writeStream.close();
                    const stats = fs.statSync(file);
                    resolve({ path: file, size: stats.size });
                });
                
                writeStream.on('error', reject);
                response.on('error', reject);
            }).on('error', reject);
        };
        
        doRequest(url);
    });
}

function extractAndDeploy(zipPath) {
    const extractDir = path.join(TEMP_DIR, 'extracted');
    fs.mkdirSync(extractDir, { recursive: true });
    
    // Extract (ignore backslash warnings from Windows-created ZIPs)
    try {
        execSync(`unzip -o ${zipPath} -d ${extractDir} 2>&1`, { encoding: 'utf8' });
    } catch (e) {
        // unzip may exit non-zero for warnings, check if files were actually extracted
        if (!fs.existsSync(extractDir) || fs.readdirSync(extractDir).length === 0) {
            throw new Error('Extraction failed: ' + (e.message || 'unknown error'));
        }
        console.log('[UPDATE] unzip had warnings but extraction succeeded');
    }
    
    // Verify index.js exists (valid SvelteKit adapter-node build)
    if (!fs.existsSync(path.join(extractDir, 'index.js'))) {
        throw new Error('Invalid build: index.js not found in ZIP');
    }
    
    // Stop frontend service
    try {
        execSync('systemctl stop aqura-frontend', { encoding: 'utf8' });
    } catch (e) {
        console.log('Warning: could not stop aqura-frontend:', e.message);
    }
    
    // Backup version info if exists
    let oldVersion = null;
    try {
        if (fs.existsSync(VERSION_FILE)) {
            oldVersion = JSON.parse(fs.readFileSync(VERSION_FILE, 'utf8'));
        }
    } catch (e) { /* ignore */ }
    
    // Replace build directory contents
    // Keep .env file
    const envContent = fs.existsSync(path.join(BUILD_DIR, '.env')) 
        ? fs.readFileSync(path.join(BUILD_DIR, '.env'), 'utf8')
        : null;
    
    // Remove old build files (but not .env or .aqura-version.json)
    execSync(`find ${BUILD_DIR} -mindepth 1 -not -name '.env' -not -name '.aqura-version.json' -delete 2>/dev/null || true`);
    
    // Copy new files
    execSync(`cp -a ${extractDir}/* ${BUILD_DIR}/`);
    
    // Restore .env if it existed
    if (envContent && !fs.existsSync(path.join(BUILD_DIR, '.env'))) {
        fs.writeFileSync(path.join(BUILD_DIR, '.env'), envContent);
    }
    
    // Start frontend service
    execSync('systemctl start aqura-frontend', { encoding: 'utf8' });
    
    // Clean up
    execSync(`rm -rf ${TEMP_DIR}`);
    
    return { oldVersion };
}

const server = http.createServer(async (req, res) => {
    // CORS headers
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    
    if (req.method === 'OPTIONS') {
        res.writeHead(204);
        res.end();
        return;
    }
    
    const sendJson = (statusCode, data) => {
        res.writeHead(statusCode, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(data));
    };

    try {
        // Health check
        if (req.url === '/health' && req.method === 'GET') {
            sendJson(200, { ok: true, uptime: Math.floor((Date.now() - startTime) / 1000) });
            return;
        }

        // Status endpoint
        if (req.url === '/status' && req.method === 'GET') {
            const versionInfo = getVersionInfo();
            const frontendStatus = getFrontendStatus();
            sendJson(200, {
                ok: true,
                version: versionInfo.version,
                build_id: versionInfo.build_id,
                updated_at: versionInfo.updated_at,
                frontend_service: frontendStatus,
                update_service_uptime: Math.floor((Date.now() - startTime) / 1000)
            });
            return;
        }

        // Update endpoint
        if (req.url === '/update' && req.method === 'POST') {
            let body = '';
            await new Promise((resolve, reject) => {
                req.on('data', chunk => { body += chunk; });
                req.on('end', resolve);
                req.on('error', reject);
            });

            let payload;
            try {
                payload = JSON.parse(body);
            } catch (e) {
                sendJson(400, { ok: false, error: 'Invalid JSON body' });
                return;
            }

            const { download_url, version, build_id } = payload;
            if (!download_url) {
                sendJson(400, { ok: false, error: 'Missing download_url' });
                return;
            }

            console.log(`[UPDATE] Starting update to version ${version || 'unknown'} from ${download_url}`);
            
            // Download the ZIP
            console.log('[UPDATE] Downloading build ZIP...');
            const downloadResult = await downloadFile(download_url);
            console.log(`[UPDATE] Downloaded ${(downloadResult.size / 1024 / 1024).toFixed(1)} MB`);
            
            // Extract and deploy
            console.log('[UPDATE] Extracting and deploying...');
            const deployResult = extractAndDeploy(downloadResult.path);
            
            // Save version info
            saveVersionInfo(version || 'unknown', build_id || null);
            console.log(`[UPDATE] Successfully updated to version ${version}`);
            
            // Wait a moment for service to stabilize
            await new Promise(r => setTimeout(r, 2000));
            
            const frontendStatus = getFrontendStatus();
            
            sendJson(200, {
                ok: true,
                message: `Frontend updated to ${version || 'latest'}`,
                version: version,
                build_id: build_id,
                previous_version: deployResult.oldVersion?.version || 'unknown',
                frontend_service: frontendStatus,
                deployed_at: new Date().toISOString()
            });
            return;
        }

        // 404 for everything else
        sendJson(404, { ok: false, error: 'Not found' });

    } catch (err) {
        console.error('[ERROR]', err);
        sendJson(500, { ok: false, error: err.message || 'Internal server error' });
    }
});

server.listen(PORT, '0.0.0.0', () => {
    console.log(`Aqura Frontend Update Service running on port ${PORT}`);
    console.log(`  GET  /health  → Health check`);
    console.log(`  GET  /status  → Current version & service status`);
    console.log(`  POST /update  → Download & deploy new build`);
});
