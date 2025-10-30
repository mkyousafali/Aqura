@echo off
REM Migration Helper Script for Aqura Database (Windows)
REM Usage: run_migration.bat [database_name] [host] [port] [username]

setlocal enabledelayedexpansion

REM Default values
set DB_NAME=%1
if "%DB_NAME%"=="" set DB_NAME=aqura_db

set DB_HOST=%2
if "%DB_HOST%"=="" set DB_HOST=localhost

set DB_PORT=%3
if "%DB_PORT%"=="" set DB_PORT=5432

set DB_USER=%4
if "%DB_USER%"=="" set DB_USER=postgres

echo 🚀 Aqura Database Migration Script
echo ==================================
echo Database: %DB_NAME%
echo Host: %DB_HOST%:%DB_PORT%
echo User: %DB_USER%
echo.

REM Check if psql is available
where psql >nul 2>nul
if %errorlevel% neq 0 (
    echo ❌ Error: psql command not found. Please install PostgreSQL client tools.
    pause
    exit /b 1
)

REM Check if migration files exist
if not exist "master_migration.sql" (
    echo ❌ Error: master_migration.sql not found. Please run from migrations directory.
    pause
    exit /b 1
)

echo 🔍 Pre-migration checks...

REM Test database connection
psql -h %DB_HOST% -p %DB_PORT% -U %DB_USER% -d postgres -c "SELECT 1;" >nul 2>nul
if %errorlevel% neq 0 (
    echo ❌ Error: Cannot connect to database server.
    echo Please check your connection parameters and ensure PostgreSQL is running.
    pause
    exit /b 1
)

echo ✅ Database connection successful

REM Check if database exists
psql -h %DB_HOST% -p %DB_PORT% -U %DB_USER% -lqt | findstr /C:"%DB_NAME%" >nul
if %errorlevel% neq 0 (
    echo 📦 Creating database: %DB_NAME%
    createdb -h %DB_HOST% -p %DB_PORT% -U %DB_USER% %DB_NAME%
    
    if !errorlevel! equ 0 (
        echo ✅ Database created successfully
    ) else (
        echo ❌ Error: Failed to create database
        pause
        exit /b 1
    )
) else (
    echo ✅ Database exists
)

echo.
echo 🚀 Starting migration...
echo ========================

REM Run the master migration
echo 📜 Executing master migration script...
psql -h %DB_HOST% -p %DB_PORT% -U %DB_USER% -d %DB_NAME% -f master_migration.sql
if %errorlevel% equ 0 (
    echo ✅ Master migration completed successfully
) else (
    echo ❌ Error: Migration failed
    echo Please check the error messages above and fix any issues.
    pause
    exit /b 1
)

echo.
echo 🔍 Running validation checks...
echo ===============================

REM Run validation
psql -h %DB_HOST% -p %DB_PORT% -U %DB_USER% -d %DB_NAME% -f validate_migration.sql
if %errorlevel% equ 0 (
    echo ✅ Validation completed
) else (
    echo ⚠️ Warning: Validation had issues
)

echo.
echo 🎉 Migration process completed!
echo ==============================
echo.
echo 📚 Next Steps:
echo 1. Review the validation results above
echo 2. Test your application connection to the database
echo 3. Configure your environment variables:
echo    - DATABASE_URL=postgresql://%DB_USER%:password@%DB_HOST%:%DB_PORT%/%DB_NAME%
echo    - SUPABASE_DB_URL (if using Supabase)
echo.
echo 📖 For more information, see README.md
echo.
pause