import re

file = r"d:\Aqura\frontend\src\lib\components\desktop-interface\master\hr\PrepareSalaryStatementWindow.svelte"
with open(file, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add unapproved override check inside shift block (after incompleteDayDeduction checks, before closing })
old1 = (
    "if (_incompDedOvr !== undefined) { incompleteDayDeduction = _incompDedOvr; }\n"
    "\t\t\t\t\t\t\t\t\t\t\t\telse if (row.totalIncompleteDays > 0) { incompleteDayDeduction = row.totalIncompleteDays * shiftHoursPerDay * hourlyRate; }\n"
    "\t\t\t\t\t\t\t\t\t\t\t\t}"
)
new1 = (
    "if (_incompDedOvr !== undefined) { incompleteDayDeduction = _incompDedOvr; }\n"
    "\t\t\t\t\t\t\t\t\t\t\t\telse if (row.totalIncompleteDays > 0) { incompleteDayDeduction = row.totalIncompleteDays * shiftHoursPerDay * hourlyRate; }\n"
    "\t\t\t\t\t\t\t\t\t\t\t\tif (_unapDedOvr !== undefined) { unapprovedLeaveDeduction = _unapDedOvr; }\n"
    "\t\t\t\t\t\t\t\t\t\t\t\t}"
)

count1 = content.count(old1)
print(f"Pattern 1 matches: {count1}")
content = content.replace(old1, new1)

# 2. Add unapprovedLeaveDeduction to net salary formula (all 3)
old2 = "const netSalary = grossWorkedSalary - (gosiDed + lateDeduction + underWorkedDeduction + salaryAdvanceDed + loanDed + penaltiesDed + incompleteDayDeduction + posShortageDed + otherDed);"
new2 = "const netSalary = grossWorkedSalary - (gosiDed + lateDeduction + underWorkedDeduction + unapprovedLeaveDeduction + salaryAdvanceDed + loanDed + penaltiesDed + incompleteDayDeduction + posShortageDed + otherDed);"

count2 = content.count(old2)
print(f"Pattern 2 matches: {count2}")
content = content.replace(old2, new2)

with open(file, 'w', encoding='utf-8') as f:
    f.write(content)

print("Done")
