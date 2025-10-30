import { createClient } from '@supabase/supabase-js';
import fs from 'fs';
import path from 'path';

// Load environment variables
import dotenv from 'dotenv';
dotenv.config({ path: './frontend/.env' });

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

console.log('Environment check:');
console.log('Supabase URL:', supabaseUrl ? 'Set' : 'Missing');
console.log('Service Key:', supabaseServiceKey ? 'Set' : 'Missing');

if (!supabaseUrl || !supabaseServiceKey) {
    console.error('Missing required environment variables');
    process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function extractCompleteSchema() {
    console.log('🔍 Extracting complete database schema...\n');
    
    const schemaData = {
        metadata: {
            extractedAt: new Date().toISOString(),
            supabaseUrl: supabaseUrl,
            totalTables: 0,
            totalStorageBuckets: 0,
            totalTriggers: 0,
            totalPolicies: 0
        },
        tables: {},
        storageBuckets: {},
        triggers: [],
        policies: [],
        edgeFunctions: [],
        customTypes: {},
        views: {},
        functions: []
    };

    try {
        // 1. Get all tables using a simple SQL query
        console.log('📊 Getting all tables...');
        const { data: tableList, error: tableError } = await supabase
            .from('information_schema.tables')
            .select('table_name')
            .eq('table_schema', 'public')
            .eq('table_type', 'BASE TABLE');

        if (tableError) {
            console.log('Trying alternative method to get tables...');
            
            // Use PostgREST openapi endpoint for table discovery
            const response = await fetch(`${supabaseUrl}/rest/v1/`, {
                headers: {
                    'Authorization': `Bearer ${supabaseServiceKey}`,
                    'apikey': supabaseServiceKey
                }
            });
            
            const openApiSpec = await response.json();
            const tableNames = Object.keys(openApiSpec.definitions || {});
            
            console.log(`Found ${tableNames.length} tables via OpenAPI spec`);
            
            for (const tableName of tableNames) {
                await getTableSchemaSimple(tableName, schemaData);
            }
        } else {
            console.log(`Found ${tableList.length} tables via information_schema`);
            
            for (const table of tableList) {
                await getTableSchemaDetailed(table.table_name, schemaData);
            }
        }

        // 2. Get storage buckets
        console.log('\n🪣 Getting storage buckets...');
        await getStorageBuckets(schemaData);

        // 3. Get edge functions from file system
        console.log('🔄 Getting edge functions...');
        await getEdgeFunctions(schemaData);

        // 4. Get database functions
        console.log('🔧 Getting database functions...');
        await getDatabaseFunctions(schemaData);

        // Update metadata
        schemaData.metadata.totalTables = Object.keys(schemaData.tables).length;
        schemaData.metadata.totalStorageBuckets = Object.keys(schemaData.storageBuckets).length;
        schemaData.metadata.totalTriggers = schemaData.triggers.length;
        schemaData.metadata.totalPolicies = schemaData.policies.length;

        // Save to file
        const outputPath = path.join(process.cwd(), 'DATABASE_SCHEMA_REFERENCE.json');
        fs.writeFileSync(outputPath, JSON.stringify(schemaData, null, 2));
        
        console.log(`\n✅ Complete database schema extracted!`);
        console.log(`📁 Saved to: ${outputPath}`);
        console.log(`📊 Summary:`);
        console.log(`   - Tables: ${schemaData.metadata.totalTables}`);
        console.log(`   - Storage Buckets: ${schemaData.metadata.totalStorageBuckets}`);
        console.log(`   - Database Functions: ${schemaData.functions.length}`);
        console.log(`   - Edge Functions: ${schemaData.edgeFunctions.length}`);

        // Also create a markdown version
        await createMarkdownReference(schemaData);

    } catch (error) {
        console.error('❌ Error extracting schema:', error);
    }
}

async function getTableSchemaDetailed(tableName, schemaData) {
    try {
        console.log(`  📋 Processing table: ${tableName}`);
        
        // Get columns
        const { data: columns, error: columnsError } = await supabase
            .from('information_schema.columns')
            .select('*')
            .eq('table_name', tableName)
            .eq('table_schema', 'public')
            .order('ordinal_position');

        // Get constraints
        const { data: constraints } = await supabase
            .from('information_schema.table_constraints')
            .select('*')
            .eq('table_name', tableName)
            .eq('table_schema', 'public');

        // Get foreign keys
        const { data: foreignKeys } = await supabase
            .from('information_schema.key_column_usage')
            .select('*')
            .eq('table_name', tableName)
            .eq('table_schema', 'public');

        schemaData.tables[tableName] = {
            columns: columns || [],
            constraints: constraints || [],
            foreignKeys: foreignKeys || [],
            lastUpdated: new Date().toISOString()
        };

        if (columnsError) {
            console.log(`    ⚠️ Column access limited for ${tableName}`);
        }

    } catch (error) {
        console.log(`    ⚠️ Error getting detailed schema for ${tableName}:`, error.message);
        await getTableSchemaSimple(tableName, schemaData);
    }
}

async function getTableSchemaSimple(tableName, schemaData) {
    try {
        console.log(`  📋 Processing table (simple): ${tableName}`);
        
        // Just verify table exists and get basic info
        const { data, error } = await supabase
            .from(tableName)
            .select('*')
            .limit(0);

        if (error) {
            schemaData.tables[tableName] = {
                error: error.message,
                lastUpdated: new Date().toISOString()
            };
        } else {
            schemaData.tables[tableName] = {
                exists: true,
                note: 'Table exists but detailed schema requires additional permissions',
                lastUpdated: new Date().toISOString()
            };
        }

    } catch (error) {
        console.log(`    ⚠️ Error accessing ${tableName}:`, error.message);
        schemaData.tables[tableName] = {
            error: error.message,
            lastUpdated: new Date().toISOString()
        };
    }
}

async function getStorageBuckets(schemaData) {
    try {
        const { data: buckets, error } = await supabase.storage.listBuckets();
        
        if (error) {
            console.log(`    ⚠️ Error getting storage buckets:`, error.message);
            return;
        }

        for (const bucket of buckets || []) {
            console.log(`  🪣 Processing bucket: ${bucket.name}`);
            
            // Get bucket details and sample files
            const { data: files } = await supabase.storage
                .from(bucket.name)
                .list('', { limit: 5 });

            // Try to get bucket info
            const { data: bucketInfo } = await supabase.storage
                .from(bucket.name)
                .list('', { limit: 1, offset: 0 });

            schemaData.storageBuckets[bucket.name] = {
                ...bucket,
                sampleFiles: files || [],
                fileCount: bucketInfo ? bucketInfo.length : 'Unknown',
                lastUpdated: new Date().toISOString()
            };
        }
    } catch (error) {
        console.log(`    ⚠️ Error getting storage buckets:`, error.message);
    }
}

async function getDatabaseFunctions(schemaData) {
    try {
        // Try to get database functions
        const { data: functions } = await supabase
            .from('information_schema.routines')
            .select('routine_name, routine_type, data_type')
            .eq('routine_schema', 'public');

        if (functions) {
            for (const func of functions) {
                console.log(`  🔧 Found function: ${func.routine_name}`);
                schemaData.functions.push(func);
            }
        }
    } catch (error) {
        console.log(`    ⚠️ Error getting database functions:`, error.message);
    }
}

async function getEdgeFunctions(schemaData) {
    try {
        // Edge functions are in the supabase/functions directory
        const functionsDir = path.join(process.cwd(), 'supabase', 'functions');
        if (fs.existsSync(functionsDir)) {
            const functionNames = fs.readdirSync(functionsDir, { withFileTypes: true })
                .filter(dirent => dirent.isDirectory())
                .map(dirent => dirent.name);

            for (const functionName of functionNames) {
                console.log(`  🔄 Found edge function: ${functionName}`);
                const functionPath = path.join(functionsDir, functionName);
                const indexPath = path.join(functionPath, 'index.ts');
                
                let functionInfo = {
                    name: functionName,
                    path: functionPath.replace(process.cwd(), ''),
                    hasIndex: fs.existsSync(indexPath),
                    files: []
                };

                // Get all files in the function directory
                try {
                    const files = fs.readdirSync(functionPath);
                    functionInfo.files = files;
                } catch (err) {
                    functionInfo.files = ['Error reading directory'];
                }

                if (functionInfo.hasIndex) {
                    try {
                        const indexContent = fs.readFileSync(indexPath, 'utf8');
                        functionInfo.preview = indexContent.substring(0, 300) + (indexContent.length > 300 ? '...' : '');
                        
                        // Extract basic info from the function
                        const lines = indexContent.split('\n');
                        const description = lines.find(line => 
                            line.includes('//') && 
                            (line.toLowerCase().includes('description') || 
                             line.toLowerCase().includes('purpose') ||
                             line.toLowerCase().includes('@description'))
                        );
                        if (description) {
                            functionInfo.description = description.replace(/\/\/\s*(@description\s*)?/i, '').trim();
                        }
                    } catch (err) {
                        functionInfo.error = 'Could not read index.ts';
                    }
                }

                schemaData.edgeFunctions.push(functionInfo);
            }
        } else {
            console.log(`    📁 Supabase functions directory not found at: ${functionsDir}`);
        }
    } catch (error) {
        console.log(`    ⚠️ Error getting edge functions:`, error.message);
    }
}

async function createMarkdownReference(schemaData) {
    const mdPath = path.join(process.cwd(), 'DATABASE_SCHEMA_REFERENCE.md');
    
    let markdown = `# Aqura Database Schema Reference

*Generated on ${schemaData.metadata.extractedAt}*

## Overview

- **Database URL**: ${schemaData.metadata.supabaseUrl}
- **Total Tables**: ${schemaData.metadata.totalTables}
- **Storage Buckets**: ${schemaData.metadata.totalStorageBuckets}
- **Database Functions**: ${schemaData.functions.length}
- **Edge Functions**: ${schemaData.edgeFunctions.length}

## Database Tables

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

    Object.entries(tableGroups).sort().forEach(([prefix, tables]) => {
        markdown += `### ${prefix.toUpperCase()} Tables (${tables.length} tables)\n\n`;
        tables.sort().forEach(tableName => {
            markdown += `#### \`${tableName}\`\n\n`;
            const table = schemaData.tables[tableName];
            
            if (table.error) {
                markdown += `*❌ Error: ${table.error}*\n\n`;
                return;
            }

            if (table.exists && table.note) {
                markdown += `*✅ ${table.note}*\n\n`;
                return;
            }

            if (table.columns && Array.isArray(table.columns) && table.columns.length > 0) {
                markdown += `| Column | Type | Nullable | Default | Max Length |\n`;
                markdown += `|--------|------|----------|---------|------------|\n`;
                table.columns.forEach(col => {
                    const colName = col.column_name || 'Unknown';
                    const colType = col.data_type || 'Unknown';
                    const nullable = col.is_nullable || 'Unknown';
                    const defaultVal = col.column_default || '';
                    const maxLength = col.character_maximum_length || '';
                    markdown += `| ${colName} | ${colType} | ${nullable} | ${defaultVal} | ${maxLength} |\n`;
                });
                markdown += `\n`;

                // Add constraints if available
                if (table.constraints && table.constraints.length > 0) {
                    markdown += `**Constraints:**\n`;
                    table.constraints.forEach(constraint => {
                        markdown += `- ${constraint.constraint_type}: ${constraint.constraint_name}\n`;
                    });
                    markdown += `\n`;
                }

                // Add foreign keys if available
                if (table.foreignKeys && table.foreignKeys.length > 0) {
                    markdown += `**Foreign Keys:**\n`;
                    table.foreignKeys.forEach(fk => {
                        markdown += `- ${fk.column_name} → ${fk.referenced_table_name}.${fk.referenced_column_name}\n`;
                    });
                    markdown += `\n`;
                }
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
            if (bucket.sampleFiles && bucket.sampleFiles.length > 0) {
                markdown += `- **Sample Files**: ${bucket.sampleFiles.map(f => f.name).join(', ')}\n`;
            }
            markdown += `\n`;
        });
    }

    // Database Functions
    if (schemaData.functions.length > 0) {
        markdown += `## Database Functions\n\n`;
        schemaData.functions.forEach(func => {
            markdown += `### \`${func.routine_name}\`\n\n`;
            markdown += `- **Type**: ${func.routine_type}\n`;
            markdown += `- **Returns**: ${func.data_type}\n\n`;
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
            
            if (func.error) {
                markdown += `\n*❌ ${func.error}*\n`;
            }
            
            markdown += `\n`;
        });
    }

    // Add generation info
    markdown += `\n---\n\n*This reference was automatically generated from the Aqura database schema on ${schemaData.metadata.extractedAt}*\n`;

    fs.writeFileSync(mdPath, markdown);
    console.log(`📄 Markdown reference saved to: ${mdPath}`);
}

// Run the extraction
extractCompleteSchema();