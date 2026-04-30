const fs = require('fs');
const file = 'd:\\Aqura\\frontend\\src\\lib\\components\\desktop-interface\\master\\hr\\PrepareSalaryStatementWindow.svelte';
let content = fs.readFileSync(file, 'utf8');

// Fix all 3 table IIFEs: remove per-day proration, use full totalAllowances as gross
const old = [
	'\t\t\t\t\t\t\t\t\t\t// Calculate per-day salary',
	'\t\t\t\t\t\t\t\t\t\tconst totalAllowances = basicSal + otherAllow + accommAllow + travelAllow + foodAllow;',
	'\t\t\t\t\t\t\t\t\t\tconst perDaySalary = row.totalExpectedWorkDays > 0 ? totalAllowances / row.totalExpectedWorkDays : 0;',
	'\t\t\t\t\t\t\t\t\t\t',
	'\t\t\t\t\t\t\t\t\t\t// Calculate salary for worked days',
	'\t\t\t\t\t\t\t\t\t\tconst workedDays = editableWorkedDays[row.employeeId] !== undefined && editableWorkedDays[row.employeeId] !== \'\' ? parseFloat(editableWorkedDays[row.employeeId]) : row.totalWorkedDays;',
	'\t\t\t\t\t\t\t\t\t\tconst grossWorkedSalary = perDaySalary * workedDays;'
].join('\r\n');

const replacement = [
	'\t\t\t\t\t\t\t\t\t\t// Total Earnings = full allowances (unapproved absences deducted explicitly below)',
	'\t\t\t\t\t\t\t\t\t\tconst totalAllowances = basicSal + otherAllow + accommAllow + travelAllow + foodAllow;',
	'\t\t\t\t\t\t\t\t\t\tconst grossWorkedSalary = totalAllowances;'
].join('\r\n');

const count = content.split(old).length - 1;
console.log('IIFE matches found:', count);
content = content.split(old).join(replacement);

fs.writeFileSync(file, content, 'utf8');
console.log('Done');
