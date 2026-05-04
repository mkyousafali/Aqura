const fs = require('fs');

const svelteFile = 'D:/Aqura/frontend/src/lib/components/desktop-interface/master/hr/PrepareSalaryStatementWindow.svelte';
const newCodeFile = 'D:/Aqura/mudad_new_code.txt';

const content = fs.readFileSync(svelteFile, 'utf8');
const lines = content.split('\n');
console.log('Total lines:', lines.length);
console.log('L487:', lines[486].substring(0, 80));
console.log('L638:', lines[637].substring(0, 80));

const newCode = fs.readFileSync(newCodeFile, 'utf8');

// Lines 487-637 (1-indexed) = indices 486-636 (0-indexed)
// Replace them with newCode
const before = lines.slice(0, 486).join('\n');
const after = lines.slice(637).join('\n');
const newContent = before + '\n' + newCode + '\n' + after;

fs.writeFileSync(svelteFile, newContent, 'utf8');

const check = fs.readFileSync(svelteFile, 'utf8');
const checkLines = check.split('\n');
console.log('New total lines:', checkLines.length);
console.log('Has mudadColToNum:', check.includes('mudadColToNum'));
console.log('Has JSZipMod:', check.includes('JSZipMod'));
console.log('Has ExcelJS (bad):', check.includes('ExcelJS'));
console.log('Has findMudadHeaderRow (bad):', check.includes('findMudadHeaderRow'));
