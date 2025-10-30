import { createClient } from '@supabase/supabase-js';
import fs from 'fs';
import path from 'path';

// Load environment variables
import dotenv from 'dotenv';
dotenv.config({ path: './frontend/.env' });

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseServiceKey) {
    console.error('Missing required environment variables');
    process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function enhanceSchemaDetails() {
    console.log('🔍 Enhancing database schema with detailed information...\n');
    
    // Read the existing schema data
    const existingSchemaPath = path.join(process.cwd(), 'DATABASE_SCHEMA_REFERENCE.json');
    let schemaData;
    
    try {
        const existingData = fs.readFileSync(existingSchemaPath, 'utf8');
        schemaData = JSON.parse(existingData);
        console.log(`📖 Loaded existing schema with ${Object.keys(schemaData.tables).length} tables`);
    } catch (error) {
        console.error('❌ Could not load existing schema file:', error.message);
        process.exit(1);
    }

    try {
        // Enhance with detailed information
        console.log('🔍 Getting detailed table schemas...');
        await enhanceTableSchemas(schemaData);

        console.log('⚡ Getting triggers and functions...');
        await getTriggerDetails(schemaData);

        console.log('🔒 Getting RLS policies...');
        await getRLSDetails(schemaData);

        console.log('🏗️ Getting database structure info...');
        await getDatabaseStructure(schemaData);

        // Update metadata
        schemaData.metadata.lastEnhanced = new Date().toISOString();
        schemaData.metadata.enhancementVersion = '2.0';

        // Save enhanced schema
        const enhancedPath = path.join(process.cwd(), 'DATABASE_SCHEMA_REFERENCE_ENHANCED.json');
        fs.writeFileSync(enhancedPath, JSON.stringify(schemaData, null, 2));

        // Create enhanced markdown
        await createEnhancedMarkdown(schemaData);

        console.log(`\n✅ Enhanced database schema completed!`);
        console.log(`📁 Enhanced JSON saved to: ${enhancedPath}`);
        console.log(`📄 Enhanced Markdown saved to: DATABASE_SCHEMA_REFERENCE_ENHANCED.md`);

    } catch (error) {
        console.error('❌ Error enhancing schema:', error);
    }
}

async function enhanceTableSchemas(schemaData) {
    // Try to get detailed schema using direct SQL queries
    const tableNames = Object.keys(schemaData.tables);
    
    for (const tableName of tableNames) {
        try {
            console.log(`  📋 Enhancing: ${tableName}`);
            
            // Try to get sample data to understand structure
            const { data: sampleData, error: sampleError } = await supabase
                .from(tableName)
                .select('*')
                .limit(1);

            if (!sampleError && sampleData && sampleData.length > 0) {
                const sampleRow = sampleData[0];
                const columns = Object.keys(sampleRow).map(key => ({
                    name: key,
                    sample_value: sampleRow[key],
                    inferred_type: typeof sampleRow[key],
                    is_null: sampleRow[key] === null
                }));

                schemaData.tables[tableName] = {
                    ...schemaData.tables[tableName],
                    columns: columns,
                    has_data: true,
                    sample_row: sampleRow
                };
            } else if (!sampleError) {
                // Table exists but is empty
                schemaData.tables[tableName] = {
                    ...schemaData.tables[tableName],
                    has_data: false,
                    note: 'Table exists but is empty'
                };
            } else {
                // Handle specific error cases
                schemaData.tables[tableName] = {
                    ...schemaData.tables[tableName],
                    access_error: sampleError.message,
                    note: 'Table exists but access may be restricted'
                };
            }

        } catch (error) {
            console.log(`    ⚠️ Could not enhance ${tableName}: ${error.message}`);
            schemaData.tables[tableName] = {
                ...schemaData.tables[tableName],
                enhancement_error: error.message
            };
        }
    }
}

async function getTriggerDetails(schemaData) {
    try {
        // Get trigger information using direct queries
        const queries = [
            // Get triggers
            `SELECT 
                trigger_name, 
                event_manipulation, 
                event_object_table, 
                action_statement, 
                action_timing,
                action_orientation
            FROM information_schema.triggers 
            WHERE trigger_schema = 'public'`,
            
            // Get functions that might be triggers
            `SELECT 
                routine_name,
                routine_type,
                data_type,
                external_language
            FROM information_schema.routines 
            WHERE routine_schema = 'public' 
            AND routine_type = 'FUNCTION'`
        ];

        for (const query of queries) {
            try {
                // Use raw SQL execution
                const response = await fetch(`${supabaseUrl}/rest/v1/rpc/exec_sql`, {
                    method: 'POST',
                    headers: {
                        'Authorization': `Bearer ${supabaseServiceKey}`,
                        'apikey': supabaseServiceKey,
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({ sql: query })
                });

                if (response.ok) {
                    const result = await response.json();
                    console.log(`  ✅ Query executed successfully`);
                    
                    if (query.includes('triggers')) {
                        schemaData.triggers = result || [];
                    } else {
                        schemaData.functions = result || [];
                    }
                }
            } catch (error) {
                console.log(`    ⚠️ Query failed: ${error.message}`);
            }
        }
    } catch (error) {
        console.log(`    ⚠️ Error getting trigger details: ${error.message}`);
    }
}

async function getRLSDetails(schemaData) {
    try {
        // Try to get RLS policy information
        const rlsQuery = `
            SELECT 
                schemaname,
                tablename,
                policyname,
                permissive,
                roles,
                cmd,
                qual,
                with_check
            FROM pg_policies
            WHERE schemaname = 'public'
        `;

        const response = await fetch(`${supabaseUrl}/rest/v1/rpc/exec_sql`, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${supabaseServiceKey}`,
                'apikey': supabaseServiceKey,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ sql: rlsQuery })
        });

        if (response.ok) {
            const policies = await response.json();
            schemaData.rls_policies = policies || [];
            console.log(`  🔒 Found ${policies?.length || 0} RLS policies`);
        }
    } catch (error) {
        console.log(`    ⚠️ Error getting RLS details: ${error.message}`);
    }
}

async function getDatabaseStructure(schemaData) {
    try {
        // Get database structure information
        const structureQueries = [
            // Get table sizes (approximate)
            `SELECT 
                schemaname,
                tablename,
                attname,
                n_distinct,
                avg_width
            FROM pg_stats 
            WHERE schemaname = 'public'
            LIMIT 100`,

            // Get index information
            `SELECT 
                t.relname as table_name,
                i.relname as index_name,
                a.attname as column_name
            FROM pg_class t, pg_class i, pg_index ix, pg_attribute a
            WHERE t.oid = ix.indrelid
            AND i.oid = ix.indexrelid
            AND a.attrelid = t.oid
            AND a.attnum = ANY(ix.indkey)
            AND t.relkind = 'r'
            AND t.relname NOT LIKE 'pg_%'
            LIMIT 100`
        ];

        for (const query of structureQueries) {
            try {
                const response = await fetch(`${supabaseUrl}/rest/v1/rpc/exec_sql`, {
                    method: 'POST',
                    headers: {
                        'Authorization': `Bearer ${supabaseServiceKey}`,
                        'apikey': supabaseServiceKey,
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({ sql: query })
                });

                if (response.ok) {
                    const result = await response.json();
                    if (query.includes('pg_stats')) {
                        schemaData.table_statistics = result || [];
                    } else if (query.includes('pg_index')) {
                        schemaData.indexes = result || [];
                    }
                }
            } catch (error) {
                console.log(`    ⚠️ Structure query failed: ${error.message}`);
            }
        }
    } catch (error) {
        console.log(`    ⚠️ Error getting database structure: ${error.message}`);
    }
}

async function createEnhancedMarkdown(schemaData) {
    const mdPath = path.join(process.cwd(), 'DATABASE_SCHEMA_REFERENCE_ENHANCED.md');
    
    let markdown = `# Aqura Database Schema Reference (Enhanced)

*Generated on ${schemaData.metadata.extractedAt}*
*Enhanced on ${schemaData.metadata.lastEnhanced}*

## Overview

- **Database URL**: ${schemaData.metadata.supabaseUrl}
- **Total Tables**: ${schemaData.metadata.totalTables}
- **Storage Buckets**: ${schemaData.metadata.totalStorageBuckets}
- **Database Functions**: ${schemaData.functions?.length || 0}
- **Edge Functions**: ${schemaData.edgeFunctions.length}
- **RLS Policies**: ${schemaData.rls_policies?.length || 0}
- **Database Triggers**: ${schemaData.triggers?.length || 0}

## Table Categories

`;

    // Group tables by prefix for better organization
    const tableGroups = {};
    Object.keys(schemaData.tables).forEach(tableName => {
        const prefix = tableName.split('_')[0];
        if (!tableGroups[prefix]) {
            tableGroups[prefix] = [];
        }
        tableGroups[prefix].push(tableName);
    });

    // Create table of contents
    markdown += `### Quick Navigation\n\n`;
    Object.entries(tableGroups).sort().forEach(([prefix, tables]) => {
        markdown += `- [${prefix.toUpperCase()} Tables](#${prefix.toLowerCase()}-tables) (${tables.length} tables)\n`;
    });
    markdown += `\n`;

    // Detailed table information
    Object.entries(tableGroups).sort().forEach(([prefix, tables]) => {
        markdown += `## ${prefix.toUpperCase()} Tables\n\n`;
        
        tables.sort().forEach(tableName => {
            markdown += `### \`${tableName}\`\n\n`;
            const table = schemaData.tables[tableName];
            
            if (table.access_error) {
                markdown += `*🔒 Access Error: ${table.access_error}*\n\n`;
            } else if (table.enhancement_error) {
                markdown += `*❌ Enhancement Error: ${table.enhancement_error}*\n\n`;
            } else if (table.has_data === false) {
                markdown += `*📋 Table exists but is currently empty*\n\n`;
            } else if (table.columns && Array.isArray(table.columns)) {
                markdown += `**Columns:**\n\n`;
                markdown += `| Column | Sample Value | Type | Notes |\n`;
                markdown += `|--------|-------------|------|-------|\n`;
                
                table.columns.forEach(col => {
                    const sampleValue = col.sample_value !== null ? 
                        (typeof col.sample_value === 'string' ? `"${col.sample_value}"` : String(col.sample_value)) : 
                        'null';
                    markdown += `| ${col.name} | ${sampleValue} | ${col.inferred_type} | ${col.is_null ? 'nullable' : 'has value'} |\n`;
                });
                markdown += `\n`;
                
                if (table.sample_row) {
                    markdown += `**Sample Data Structure:**\n\`\`\`json\n${JSON.stringify(table.sample_row, null, 2)}\n\`\`\`\n\n`;
                }
            } else if (table.note) {
                markdown += `*ℹ️ ${table.note}*\n\n`;
            }
        });
    });

    // Storage Buckets
    if (Object.keys(schemaData.storageBuckets).length > 0) {
        markdown += `## Storage Buckets\n\n`;
        Object.entries(schemaData.storageBuckets).forEach(([bucketName, bucket]) => {
            markdown += `### \`${bucketName}\`\n\n`;
            markdown += `- **ID**: ${bucket.id}\n`;
            markdown += `- **Public**: ${bucket.public ? 'Yes' : 'No'}\n`;
            markdown += `- **Created**: ${bucket.created_at}\n`;
            markdown += `- **Updated**: ${bucket.updated_at}\n`;
            markdown += `- **File Count**: ${bucket.fileCount}\n`;
            
            if (bucket.sampleFiles && bucket.sampleFiles.length > 0) {
                markdown += `- **Sample Files**: \n`;
                bucket.sampleFiles.forEach(file => {
                    markdown += `  - ${file.name} (${file.metadata?.size || 'unknown size'})\n`;
                });
            }
            markdown += `\n`;
        });
    }

    // RLS Policies
    if (schemaData.rls_policies && schemaData.rls_policies.length > 0) {
        markdown += `## Row Level Security Policies\n\n`;
        const policiesByTable = {};
        schemaData.rls_policies.forEach(policy => {
            if (!policiesByTable[policy.tablename]) {
                policiesByTable[policy.tablename] = [];
            }
            policiesByTable[policy.tablename].push(policy);
        });

        Object.entries(policiesByTable).sort().forEach(([tableName, policies]) => {
            markdown += `### \`${tableName}\` Policies\n\n`;
            policies.forEach(policy => {
                markdown += `#### \`${policy.policyname}\`\n\n`;
                markdown += `- **Command**: ${policy.cmd}\n`;
                markdown += `- **Roles**: ${JSON.stringify(policy.roles)}\n`;
                markdown += `- **Permissive**: ${policy.permissive}\n`;
                if (policy.qual) markdown += `- **Condition**: \`${policy.qual}\`\n`;
                if (policy.with_check) markdown += `- **With Check**: \`${policy.with_check}\`\n`;
                markdown += `\n`;
            });
        });
    }

    // Database Functions
    if (schemaData.functions && schemaData.functions.length > 0) {
        markdown += `## Database Functions\n\n`;
        schemaData.functions.forEach(func => {
            markdown += `### \`${func.routine_name}\`\n\n`;
            markdown += `- **Type**: ${func.routine_type}\n`;
            markdown += `- **Returns**: ${func.data_type}\n`;
            markdown += `- **Language**: ${func.external_language}\n\n`;
        });
    }

    // Triggers
    if (schemaData.triggers && schemaData.triggers.length > 0) {
        markdown += `## Database Triggers\n\n`;
        schemaData.triggers.forEach(trigger => {
            markdown += `### \`${trigger.trigger_name}\`\n\n`;
            markdown += `- **Table**: ${trigger.event_object_table}\n`;
            markdown += `- **Event**: ${trigger.event_manipulation}\n`;
            markdown += `- **Timing**: ${trigger.action_timing}\n`;
            markdown += `- **Statement**: ${trigger.action_statement}\n\n`;
        });
    }

    // Edge Functions
    if (schemaData.edgeFunctions.length > 0) {
        markdown += `## Edge Functions\n\n`;
        schemaData.edgeFunctions.forEach(func => {
            markdown += `### \`${func.name}\`\n\n`;
            markdown += `- **Path**: ${func.path}\n`;
            markdown += `- **Has Index**: ${func.hasIndex ? 'Yes' : 'No'}\n`;
            markdown += `- **Files**: ${func.files.join(', ')}\n`;
            
            if (func.description) {
                markdown += `- **Description**: ${func.description}\n`;
            }
            
            if (func.preview) {
                markdown += `\n**Code Preview:**\n\`\`\`typescript\n${func.preview}\n\`\`\`\n`;
            }
            markdown += `\n`;
        });
    }

    // Database Statistics
    if (schemaData.table_statistics && schemaData.table_statistics.length > 0) {
        markdown += `## Database Statistics\n\n`;
        markdown += `| Table | Column | Distinct Values | Avg Width |\n`;
        markdown += `|-------|--------|----------------|----------|\n`;
        schemaData.table_statistics.forEach(stat => {
            markdown += `| ${stat.tablename} | ${stat.attname} | ${stat.n_distinct} | ${stat.avg_width} |\n`;
        });
        markdown += `\n`;
    }

    // Index Information
    if (schemaData.indexes && schemaData.indexes.length > 0) {
        markdown += `## Database Indexes\n\n`;
        markdown += `| Table | Index | Column |\n`;
        markdown += `|-------|-------|--------|\n`;
        schemaData.indexes.forEach(index => {
            markdown += `| ${index.table_name} | ${index.index_name} | ${index.column_name} |\n`;
        });
        markdown += `\n`;
    }

    // Add generation info
    markdown += `\n---\n\n*This enhanced reference was automatically generated from the Aqura database schema on ${schemaData.metadata.extractedAt} and enhanced on ${schemaData.metadata.lastEnhanced}*\n`;

    fs.writeFileSync(mdPath, markdown);
    console.log(`📄 Enhanced markdown reference saved to: ${mdPath}`);
}

// Run the enhancement
enhanceSchemaDetails();