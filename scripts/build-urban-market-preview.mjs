import { access } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const repoRoot = fileURLToPath(new URL('../', import.meta.url));
const sourceRoot = path.join(repoRoot, 'Urbanksa.com', 'urban-market-main');
const outputDir = path.join(repoRoot, 'frontend', 'static', 'urban-market-preview');
const previewBase = '/urban-market-preview/';
const viteEntry = path.join(sourceRoot, 'node_modules', 'vite', 'dist', 'node', 'index.js');

try {
	await access(viteEntry);
} catch {
	throw new Error('Install the original site dependencies first: npm ci --prefix Urbanksa.com/urban-market-main');
}

// This is the only generated directory that the preview build may replace.
if (path.relative(repoRoot, outputDir) !== path.join('frontend', 'static', 'urban-market-preview')) {
	throw new Error('Unexpected preview output directory');
}

const { build } = await import(pathToFileURL(viteEntry).href);
const previousCwd = process.cwd();
try {
	// The original Tailwind configuration scans paths relative to its project.
	process.chdir(sourceRoot);
	await build({
		root: sourceRoot,
		configFile: path.join(sourceRoot, 'vite.config.ts'),
		base: previewBase,
		plugins: [{
			name: 'aqura-urban-market-preview',
			enforce: 'pre',
			transform(code, id) {
				const filename = id.split('?')[0].replaceAll('\\', '/');
				if (!filename.startsWith(sourceRoot.replaceAll('\\', '/') + '/src/')) return;
				let adapted = code.replace(/(["'`])\/(lovable-uploads\/|favicon\.ico)/g, `$1${previewBase}$2`);
				if (filename.endsWith('/src/App.tsx')) {
					// Keep navigation inside the preview without taking over Aqura's URL.
					adapted = adapted.replace('BrowserRouter, Routes, Route', 'MemoryRouter as BrowserRouter, Routes, Route');
					adapted = adapted.replace('content="index, follow"', 'content="noindex, nofollow"');
				}
				if (filename.endsWith('/src/components/layout/Navbar.tsx')) {
					adapted = adapted.replace("import { Link } from 'react-router-dom'", "import { Link, useLocation } from 'react-router-dom'");
					adapted = adapted.replace('const Navbar: React.FC = () => {', 'const Navbar: React.FC = () => {\n  const previewLocation = useLocation();');
					adapted = adapted.replaceAll('window.location.pathname', 'previewLocation.pathname');
				}
				return { code: adapted, map: null };
			}
		}],
		build: { outDir: outputDir, emptyOutDir: true }
	});
} finally {
	process.chdir(previousCwd);
}
