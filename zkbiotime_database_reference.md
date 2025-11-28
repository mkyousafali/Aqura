# ZKBioTime Database Reference

**Database:** zkbiotime  
**Server:** SQL Server Express  
**Total Tables:** 142  
**Generated:** November 28, 2025

## BIO TIME 8.5 INSTALLATION GUIDE (SQL SERVER + SSMS)
---------------------------------------------------

### 1. Install SQL Server 2019 Express
   - Run SQL Server installer
   - Choose "Basic" setup
   - Wait for installation to finish

### 2. Install SQL Server Management Studio (SSMS)
   - Run SSMS installer
   - Open SSMS after installation

### 3. Enable SQL Authentication (Mixed Mode)
   - Open SSMS
   - Connect using Windows Authentication
   - Right-click server > Properties
   - Select Security
   - Choose "SQL Server and Windows Authentication Mode"
   - Click OK
   - Right-click server > Restart

### 4. Enable SA Login and Set Password
   - In SSMS: Expand Security > Logins
   - Right-click "sa" > Properties
   - Set password (example: Urban@123)
   - Status tab: Enable login & Grant permission
   - Click OK

### 5. Enable TCP/IP for SQL Server
   - Open SQL Server Configuration Manager
   - SQL Server Network Configuration > Protocols for SQLEXPRESS
   - Enable TCP/IP
   - Double-click TCP/IP > IP Addresses
   - Scroll to "IPAll"
   - Clear "TCP Dynamic Ports"
   - Set "TCP Port" to 1433
   - Apply > OK
   - Restart SQL Server service

### 6. Install All Required Microsoft Visual C++ Runtimes
   (Use winget in CMD as Administrator)

   ```cmd
   winget install --id Microsoft.VCRedist.2008.x64 --source winget
   winget install --id Microsoft.VCRedist.2008.x86 --source winget
   winget install --id Microsoft.VCRedist.2010.x64 --source winget
   winget install --id Microsoft.VCRedist.2010.x86 --source winget
   winget install --id Microsoft.VCRedist.2013.x64 --source winget
   winget install --id Microsoft.VCRedist.2013.x86 --source winget
   winget install --id Microsoft.VCRedist.2015+.x64 --source winget
   winget install --id Microsoft.VCRedist.2015+.x86 --source winget
   ```

   - Restart PC after installing all packages

### 7. Start BioTime 8.5 Installer
   - Click Start
   - Service port: 3030
   - Check "Add Firewall Exception"
   - Click Next

### 8. Choose Database Type
   - Select "Other Database"
   - Choose "MS SQL Server"
   - Click Next

### 9. Configure Database Connection
   ```
   Database Name: zkbiotime
   Username: sa
   Password: (your SA password)
   Host Address: 127.0.0.1
   Port Number: 1433
   ```

   - Click "Test Connection"
   - Click "Post" to create database
   - Click Next

### 10. Finish BioTime Installation
    - Let installer complete copying files
    - Click Finish

### 11. Start BioTime Services
    - Press Windows + R
    - Type: services.msc
    - Find and ensure these are running:
      - bio-server
      - bio-proxy
      - bio-apache0

    - If any service is stopped, right-click > Start

### 12. Open BioTime Web Application
    - Open browser
    - Go to: http://127.0.0.1:3030/
    - BioTime login page should appear

---

## 🔗 **DATA ACCESS FOR CUSTOM PWA/APPLICATIONS**
---------------------------------------------------

### **Database Connection Details**
```
Server: localhost\SQLEXPRESS
Database: zkbiotime
Username: sa
Password: Urban@123
Port: 1433
Connection String: Server=localhost\SQLEXPRESS;Database=zkbiotime;User Id=sa;Password=Urban@123;TrustServerCertificate=true;
```

### **1. Direct Database Access Methods**

#### **A. Using Node.js (mssql package)**
```javascript
const sql = require('mssql');

const config = {
    user: 'sa',
    password: 'Urban@123',
    server: 'localhost\\SQLEXPRESS',
    database: 'zkbiotime',
    options: {
        encrypt: false,
        trustServerCertificate: true
    }
};

// Get attendance data
async function getAttendanceData(empCode = null) {
    try {
        const pool = await sql.connect(config);
        let query = `SELECT emp_code, punch_time, punch_state, terminal_alias, 
                            verify_type, work_code, gps_location
                     FROM iclock_transaction `;
        
        if (empCode) {
            query += `WHERE emp_code = '${empCode}' `;
        }
        
        query += `ORDER BY punch_time DESC`;
        
        const result = await pool.request().query(query);
        return result.recordset;
    } catch (err) {
        console.error('Database error:', err);
    }
}

// Get employee list
async function getEmployees() {
    const pool = await sql.connect(config);
    const result = await pool.request().query(`
        SELECT e.id, e.emp_code, e.first_name, e.last_name, 
               e.email, d.dept_name
        FROM personnel_employee e
        LEFT JOIN personnel_department d ON e.department_id = d.id
        ORDER BY e.emp_code
    `);
    return result.recordset;
}
```

#### **B. Using Python (pyodbc)**
```python
import pyodbc

def connect_to_zkbiotime():
    connection_string = '''
        DRIVER={SQL Server};
        SERVER=localhost\SQLEXPRESS;
        DATABASE=zkbiotime;
        UID=sa;
        PWD=Urban@123;
        TrustServerCertificate=yes;
    '''
    return pyodbc.connect(connection_string)

def get_attendance_data(emp_code=None):
    conn = connect_to_zkbiotime()
    cursor = conn.cursor()
    
    if emp_code:
        query = """
            SELECT emp_code, punch_time, punch_state, terminal_alias
            FROM iclock_transaction 
            WHERE emp_code = ?
            ORDER BY punch_time DESC
        """
        cursor.execute(query, emp_code)
    else:
        query = """
            SELECT emp_code, punch_time, punch_state, terminal_alias
            FROM iclock_transaction 
            ORDER BY punch_time DESC
        """
        cursor.execute(query)
    
    return cursor.fetchall()
```

#### **C. Using C# (.NET)**
```csharp
using System.Data.SqlClient;

public class ZkBioTimeAccess
{
    private string connectionString = 
        "Server=localhost\\SQLEXPRESS;Database=zkbiotime;User Id=sa;Password=Urban@123;TrustServerCertificate=true;";
    
    public async Task<List<AttendanceRecord>> GetAttendanceData(string empCode = null)
    {
        var records = new List<AttendanceRecord>();
        
        using (var connection = new SqlConnection(connectionString))
        {
            await connection.OpenAsync();
            
            string query = @"
                SELECT emp_code, punch_time, punch_state, terminal_alias, verify_type
                FROM iclock_transaction ";
            
            if (!string.IsNullOrEmpty(empCode))
                query += "WHERE emp_code = @empCode ";
                
            query += "ORDER BY punch_time DESC";
            
            using (var command = new SqlCommand(query, connection))
            {
                if (!string.IsNullOrEmpty(empCode))
                    command.Parameters.AddWithValue("@empCode", empCode);
                
                using (var reader = await command.ExecuteReaderAsync())
                {
                    while (await reader.ReadAsync())
                    {
                        records.Add(new AttendanceRecord
                        {
                            EmpCode = reader["emp_code"].ToString(),
                            PunchTime = Convert.ToDateTime(reader["punch_time"]),
                            PunchState = reader["punch_state"].ToString(),
                            TerminalAlias = reader["terminal_alias"].ToString()
                        });
                    }
                }
            }
        }
        
        return records;
    }
}
```

### **2. REST API Creation**

#### **Express.js API Endpoints**
```javascript
const express = require('express');
const sql = require('mssql');
const app = express();

app.use(express.json());

// Middleware for database connection
app.use(async (req, res, next) => {
    try {
        if (!sql.pool) {
            await sql.connect(config);
        }
        next();
    } catch (err) {
        res.status(500).json({ error: 'Database connection failed' });
    }
});

// Get all employees
app.get('/api/employees', async (req, res) => {
    try {
        const result = await sql.query`
            SELECT e.id, e.emp_code, e.first_name, e.last_name, 
                   e.email, d.dept_name
            FROM personnel_employee e
            LEFT JOIN personnel_department d ON e.department_id = d.id
            ORDER BY e.emp_code
        `;
        res.json(result.recordset);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Get attendance for specific employee
app.get('/api/attendance/:empCode', async (req, res) => {
    try {
        const { empCode } = req.params;
        const { fromDate, toDate } = req.query;
        
        let query = `
            SELECT emp_code, punch_time, punch_state, terminal_alias, 
                   verify_type, work_code, gps_location
            FROM iclock_transaction 
            WHERE emp_code = @empCode
        `;
        
        if (fromDate) query += ` AND punch_time >= @fromDate`;
        if (toDate) query += ` AND punch_time <= @toDate`;
        
        query += ` ORDER BY punch_time DESC`;
        
        const result = await sql.query(query, {
            empCode,
            fromDate,
            toDate
        });
        
        res.json(result.recordset);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Get daily attendance summary
app.get('/api/attendance/daily/:date', async (req, res) => {
    try {
        const { date } = req.params;
        const result = await sql.query`
            SELECT emp_code, 
                   MIN(punch_time) as first_punch,
                   MAX(punch_time) as last_punch,
                   COUNT(*) as total_punches
            FROM iclock_transaction 
            WHERE CAST(punch_time AS DATE) = ${date}
            GROUP BY emp_code
            ORDER BY emp_code
        `;
        res.json(result.recordset);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

app.listen(3001, () => {
    console.log('API server running on port 3001');
});
```

### **3. Key SQL Queries for PWA Development**

#### **Common Attendance Queries:**
```sql
-- Get today's attendance
SELECT emp_code, punch_time, punch_state, terminal_alias
FROM iclock_transaction 
WHERE CAST(punch_time AS DATE) = CAST(GETDATE() AS DATE)
ORDER BY punch_time DESC;

-- Get employee's monthly attendance
SELECT emp_code, punch_time, punch_state
FROM iclock_transaction 
WHERE emp_code = 'EMP001' 
  AND YEAR(punch_time) = YEAR(GETDATE())
  AND MONTH(punch_time) = MONTH(GETDATE())
ORDER BY punch_time;

-- Get late arrivals (after 9 AM)
SELECT emp_code, punch_time, punch_state
FROM iclock_transaction 
WHERE punch_state = 'I' 
  AND CAST(punch_time AS TIME) > '09:00:00'
  AND CAST(punch_time AS DATE) = CAST(GETDATE() AS DATE);

-- Get employees currently in office
SELECT DISTINCT emp_code, MAX(punch_time) as last_punch
FROM iclock_transaction 
WHERE CAST(punch_time AS DATE) = CAST(GETDATE() AS DATE)
GROUP BY emp_code
HAVING COUNT(CASE WHEN punch_state = 'I' THEN 1 END) > 
       COUNT(CASE WHEN punch_state = 'O' THEN 1 END);
```

#### **Employee Management Queries:**
```sql
-- Get all employees with departments
SELECT e.emp_code, e.first_name, e.last_name, 
       e.email, d.dept_name, p.position_name
FROM personnel_employee e
LEFT JOIN personnel_department d ON e.department_id = d.id
LEFT JOIN personnel_position p ON e.position_id = p.id
ORDER BY e.emp_code;

-- Get employee schedule
SELECT e.emp_code, s.start_date, s.end_date, 
       sh.shift_name, sh.start_time, sh.end_time
FROM personnel_employee e
JOIN att_attschedule s ON e.id = s.employee_id
JOIN att_attshift sh ON s.shift_id = sh.id
WHERE e.emp_code = 'EMP001'
  AND GETDATE() BETWEEN s.start_date AND s.end_date;
```

### **4. PWA Implementation Tips**

#### **Frontend Structure (React/Vue/Vanilla JS):**
```
src/
├── components/
│   ├── Dashboard.js
│   ├── EmployeeList.js
│   ├── AttendanceReport.js
│   └── PunchLogger.js
├── services/
│   ├── api.js
│   └── auth.js
├── utils/
│   └── dateHelper.js
└── App.js
```

#### **Service Worker for PWA:**
```javascript
// sw.js
self.addEventListener('install', (event) => {
    event.waitUntil(
        caches.open('zkbiotime-v1').then((cache) => {
            return cache.addAll([
                '/',
                '/static/js/bundle.js',
                '/static/css/main.css',
                '/manifest.json'
            ]);
        })
    );
});

self.addEventListener('fetch', (event) => {
    event.respondWith(
        caches.match(event.request).then((response) => {
            return response || fetch(event.request);
        })
    );
});
```

### **5. Security Best Practices**

- **Never expose database credentials in frontend code**
- **Use environment variables for sensitive data**
- **Implement JWT authentication**
- **Validate and sanitize all inputs**
- **Use parameterized queries to prevent SQL injection**
- **Implement role-based access control**
- **Use HTTPS in production**
- **Set up proper CORS policies**

### **6. Mobile Features**

#### **GPS-Based Attendance:**
```javascript
// Get user location for mobile punch
navigator.geolocation.getCurrentPosition(async (position) => {
    const { latitude, longitude } = position.coords;
    
    const punchData = {
        empCode: 'EMP001',
        punchTime: new Date().toISOString(),
        punchState: 'I', // or 'O'
        latitude,
        longitude,
        source: 'mobile'
    };
    
    await fetch('/api/punch', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(punchData)
    });
});
```

---

## Table Categories and Purposes

### 🔐 **Authentication & Security (9 tables)**
| Table Name | Purpose |
|------------|---------|
| `auth_group` | User groups for role-based access |
| `auth_group_permissions` | Permissions assigned to groups |
| `auth_permission` | Available system permissions |
| `auth_user` | System users and login credentials |
| `auth_user_auth_area` | User area access permissions |
| `auth_user_auth_dept` | User department access permissions |
| `auth_user_groups` | User group memberships |
| `auth_user_profile` | Extended user profile information |
| `auth_user_user_permissions` | Individual user permissions |
| `authtoken_token` | API authentication tokens |

### 👥 **Personnel Management (11 tables)**
| Table Name | Purpose |
|------------|---------|
| `personnel_area` | Geographic/organizational areas |
| `personnel_assignareaemployee` | Employee area assignments |
| `personnel_certification` | Available certifications |
| `personnel_department` | Company departments |
| `personnel_employee` | Main employee records |
| `personnel_employee_area` | Employee-area relationships |
| `personnel_employee_flow_role` | Employee workflow roles |
| `personnel_employeecertification` | Employee certifications |
| `personnel_employeeprofile` | Extended employee profiles |
| `personnel_position` | Job positions/titles |
| `personnel_resign` | Employee resignation records |

### ⏰ **Attendance Management (19 tables)**
| Table Name | Purpose |
|------------|---------|
| `att_attcalclog` | Attendance calculation logs |
| `att_attreportsetting` | Attendance report configurations |
| `att_attrule` | Attendance calculation rules |
| `att_attschedule` | Employee work schedules |
| `att_attshift` | Shift definitions |
| `att_breaktime` | Break time configurations |
| `att_changeschedule` | Schedule change requests |
| `att_departmentschedule` | Department-wide schedules |
| `att_deptattrule` | Department attendance rules |
| `att_holiday` | Holiday definitions |
| `att_leave` | Leave applications and records |
| `att_leavecategory` | Types of leave categories |
| `att_manuallog` | Manual attendance corrections |
| `att_overtime` | Overtime requests and records |
| `att_tempschedule` | Temporary schedule assignments |
| `att_timeinterval` | Time interval definitions |
| `att_timeinterval_break_time` | Break time intervals |
| `att_training` | Training attendance records |
| `att_trainingcategory` | Training categories |

### 📊 **Attendance Processing & Payloads (6 tables)**
| Table Name | Purpose |
|------------|---------|
| `att_payloadbase` | Base payload processing |
| `att_payloadbreak` | Break time payload data |
| `att_payloadexception` | Exception payload processing |
| `att_payloadmulpunchset` | Multiple punch set payloads |
| `att_payloadovertime` | Overtime payload processing |
| `att_payloadpunch` | Punch payload processing |

### 📈 **Reporting & Export (4 tables)**
| Table Name | Purpose |
|------------|---------|
| `att_reportexport` | Report export configurations |
| `att_reportexport_department` | Department-specific exports |
| `att_reportparam` | Report parameters |
| `att_shiftdetail` | Detailed shift information |
| `attparam` | Attendance parameters |

### 🏢 **Access Control System (6 tables)**
| Table Name | Purpose |
|------------|---------|
| `acc_acccombination` | Access control combinations |
| `acc_accgroups` | Access control groups |
| `acc_accholiday` | Access control holiday settings |
| `acc_accprivilege` | Access privileges |
| `acc_accterminal` | Access control terminals |
| `acc_acctimezone` | Access control time zones |

### 🖥️ **Device & Terminal Management (14 tables)**
| Table Name | Purpose |
|------------|---------|
| `iclock_biodata` | Biometric data storage |
| `iclock_biophoto` | Biometric photos |
| `iclock_deviceconfig` | Device configurations |
| `iclock_errorcommandlog` | Device error logs |
| `iclock_privatemessage` | Private messages to devices |
| `iclock_publicmessage` | Public messages to devices |
| `iclock_terminal` | Terminal/device registry |
| `iclock_terminalcommand` | Commands sent to terminals |
| `iclock_terminalcommandlog` | Terminal command execution logs |
| `iclock_terminalemployee` | Terminal-employee relationships |
| `iclock_terminallog` | Terminal activity logs |
| `iclock_terminalparameter` | Terminal configuration parameters |
| `iclock_terminaluploadlog` | Terminal data upload logs |
| `iclock_terminalworkcode` | Terminal work codes |

### 🕐 **Transaction Data (2 tables)**
| Table Name | Purpose |
|------------|---------|
| `iclock_transaction` | **Main attendance transactions (punch data)** |
| `iclock_transactionproofcmd` | Transaction proof commands |

### 💰 **Payroll Management (17 tables)**
| Table Name | Purpose |
|------------|---------|
| `payroll_deductionformula` | Deduction calculation formulas |
| `payroll_emploan` | Employee loan records |
| `payroll_emppayrollprofile` | Employee payroll profiles |
| `payroll_exceptionformula` | Exception calculation formulas |
| `payroll_extradeduction` | Extra deductions |
| `payroll_extraincrease` | Extra salary increases |
| `payroll_increasementformula` | Salary increment formulas |
| `payroll_leaveformula` | Leave calculation formulas |
| `payroll_monthlysalary` | Monthly salary records |
| `payroll_overtimeformula` | Overtime calculation formulas |
| `payroll_reimbursement` | Expense reimbursements |
| `payroll_salaryadvance` | Salary advance records |
| `payroll_salarystructure` | Salary structure definitions |
| `payroll_salarystructure_deductionformula` | Structure-deduction relationships |
| `payroll_salarystructure_exceptionformula` | Structure-exception relationships |
| `payroll_salarystructure_increasementformula` | Structure-increment relationships |
| `payroll_salarystructure_leaveformula` | Structure-leave relationships |
| `payroll_salarystructure_overtimeformula` | Structure-overtime relationships |

### 📱 **Mobile Application (6 tables)**
| Table Name | Purpose |
|------------|---------|
| `mobile_announcement` | Mobile app announcements |
| `mobile_appactionlog` | Mobile app action logs |
| `mobile_applist` | Available mobile applications |
| `mobile_appnotification` | Push notifications |
| `mobile_gpsfordepartment` | Department GPS tracking |
| `mobile_gpsforemployee` | Employee GPS tracking |

### 🔄 **Workflow Management (9 tables)**
| Table Name | Purpose |
|------------|---------|
| `workflow_abstractexception` | Workflow exceptions |
| `workflow_nodeinstance` | Workflow node instances |
| `workflow_workflowengine` | Workflow engines |
| `workflow_workflowengine_employee` | Engine-employee relationships |
| `workflow_workflowinstance` | Active workflow instances |
| `workflow_workflownode` | Workflow node definitions |
| `workflow_workflownode_approver` | Node approvers |
| `workflow_workflownode_notifier` | Node notification recipients |
| `workflow_workflowrole` | Workflow roles |

### 🔄 **Synchronization (5 tables)**
| Table Name | Purpose |
|------------|---------|
| `sync_area` | Area synchronization |
| `sync_department` | Department synchronization |
| `sync_employee` | Employee synchronization |
| `sync_job` | Job synchronization |
| `sync_leave` | Leave synchronization |

### ⚙️ **System Administration (11 tables)**
| Table Name | Purpose |
|------------|---------|
| `base_adminlog` | Administrative action logs |
| `base_adsetting` | Active Directory settings |
| `base_attparamdepts` | Department attendance parameters |
| `base_autoexporttask` | Automated export tasks |
| `base_bookmark` | User bookmarks |
| `base_dbbackuplog` | Database backup logs |
| `base_dbmigrate` | Database migration records |
| `base_emailtemplate` | Email templates |
| `base_linenotifysetting` | LINE notification settings |
| `base_sendemail` | Email sending queue |
| `base_sftpsetting` | SFTP configuration |
| `base_sysparam` | System parameters |
| `base_sysparamdept` | Department system parameters |
| `base_systemsetting` | System settings |
| `base_taskresultlog` | Task execution results |
| `base_whatsapplog` | WhatsApp integration logs |

### 🐍 **Django Framework (7 tables)**
| Table Name | Purpose |
|------------|---------|
| `django_admin_log` | Django admin interface logs |
| `django_content_type` | Django content type registry |
| `django_migrations` | Django migration history |
| `django_session` | User session data |

### 🔄 **Celery Task Queue (8 tables)**
| Table Name | Purpose |
|------------|---------|
| `celery_taskmeta` | Celery task metadata |
| `celery_tasksetmeta` | Celery task set metadata |
| `djcelery_crontabschedule` | Cron-based task schedules |
| `djcelery_intervalschedule` | Interval-based task schedules |
| `djcelery_periodictask` | Periodic task definitions |
| `djcelery_periodictasks` | Periodic task registry |
| `djcelery_taskstate` | Task execution states |
| `djcelery_workerstate` | Celery worker states |

### 🛡️ **Django Guardian (2 tables)**
| Table Name | Purpose |
|------------|---------|
| `guardian_groupobjectpermission` | Object-level group permissions |
| `guardian_userobjectpermission` | Object-level user permissions |

### 🔑 **Staff Management (1 table)**
| Table Name | Purpose |
|------------|---------|
| `staff_stafftoken` | Staff authentication tokens |

## 🎯 **Key Tables for Common Operations**

### **Attendance Data Queries:**
- **Primary:** `iclock_transaction` (all punch records)
- **Processed:** `att_payloadpunch` (processed attendance)
- **Schedules:** `att_attschedule`, `att_attshift`
- **Exceptions:** `att_leave`, `att_overtime`, `att_manuallog`

### **Employee Information:**
- **Main:** `personnel_employee`
- **Profiles:** `personnel_employeeprofile`
- **Departments:** `personnel_department`
- **Areas:** `personnel_area`

### **Device Management:**
- **Terminals:** `iclock_terminal`
- **Biometric Data:** `iclock_biodata`, `iclock_biophoto`
- **Logs:** `iclock_terminallog`, `iclock_errorcommandlog`

### **Payroll Processing:**
- **Salaries:** `payroll_monthlysalary`
- **Structure:** `payroll_salarystructure`
- **Formulas:** `payroll_*formula` tables

---

*This reference document provides an overview of all 142 tables in the zkbiotime database. For detailed column structures, use SQL queries against `INFORMATION_SCHEMA.COLUMNS`.*