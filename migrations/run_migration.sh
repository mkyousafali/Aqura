#!/bin/bash
# Migration Helper Script for Aqura Database
# Usage: ./run_migration.sh [database_name] [host] [port] [username]

# Default values
DB_NAME=${1:-aqura_db}
DB_HOST=${2:-localhost}
DB_PORT=${3:-5432}
DB_USER=${4:-postgres}

echo "🚀 Aqura Database Migration Script"
echo "=================================="
echo "Database: $DB_NAME"
echo "Host: $DB_HOST:$DB_PORT"
echo "User: $DB_USER"
echo

# Check if psql is available
if ! command -v psql &> /dev/null; then
    echo "❌ Error: psql command not found. Please install PostgreSQL client tools."
    exit 1
fi

# Check if migration files exist
if [ ! -f "master_migration.sql" ]; then
    echo "❌ Error: master_migration.sql not found. Please run from migrations directory."
    exit 1
fi

echo "🔍 Pre-migration checks..."

# Test database connection
if ! psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d postgres -c "SELECT 1;" > /dev/null 2>&1; then
    echo "❌ Error: Cannot connect to database server."
    echo "Please check your connection parameters and ensure PostgreSQL is running."
    exit 1
fi

echo "✅ Database connection successful"

# Check if database exists, create if not
if ! psql -h $DB_HOST -p $DB_PORT -U $DB_USER -lqt | cut -d \| -f 1 | grep -qw $DB_NAME; then
    echo "📦 Creating database: $DB_NAME"
    createdb -h $DB_HOST -p $DB_PORT -U $DB_USER $DB_NAME
    
    if [ $? -eq 0 ]; then
        echo "✅ Database created successfully"
    else
        echo "❌ Error: Failed to create database"
        exit 1
    fi
else
    echo "✅ Database exists"
fi

echo
echo "🚀 Starting migration..."
echo "========================"

# Run the master migration
echo "📜 Executing master migration script..."
if psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f master_migration.sql; then
    echo "✅ Master migration completed successfully"
else
    echo "❌ Error: Migration failed"
    echo "Please check the error messages above and fix any issues."
    exit 1
fi

echo
echo "🔍 Running validation checks..."
echo "==============================="

# Run validation
if psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f validate_migration.sql; then
    echo "✅ Validation completed"
else
    echo "⚠️ Warning: Validation had issues"
fi

echo
echo "🎉 Migration process completed!"
echo "=============================="
echo
echo "📚 Next Steps:"
echo "1. Review the validation results above"
echo "2. Test your application connection to the database"
echo "3. Configure your environment variables:"
echo "   - DATABASE_URL=postgresql://$DB_USER:password@$DB_HOST:$DB_PORT/$DB_NAME"
echo "   - SUPABASE_DB_URL (if using Supabase)"
echo
echo "📖 For more information, see README.md"