import { createClient } from '@supabase/supabase-js';
import fs from 'fs';
import path from 'path';

// Load environment variables
import dotenv from 'dotenv';
dotenv.config({ path: '../frontend/.env' });

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

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
        triggers: {},
        policies: {},
        edgeFunctions: [],
        customTypes: {},
        views: {}
    };

    try {
        // 1. Get all tables with detailed information
        console.log('📊 Getting table schemas...');
        const { data: tables, error: tablesError } = await supabase
            .rpc('get_table_info')
            .catch(async () => {
                // Fallback: Get tables from information_schema
                const { data, error } = await supabase
                    .from('information_schema.tables')
                    .select('*')
                    .eq('table_schema', 'public');
                
                if (error) throw error;
                return { data, error: null };
            });

        if (tablesError) {
            console.log('Using PostgREST API to get tables...');
            // Get tables via PostgREST introspection
            const response = await fetch(`${supabaseUrl}/rest/v1/`, {
                headers: {
                    'Authorization': `Bearer ${supabaseServiceKey}`,
                    'apikey': supabaseServiceKey
                }
            });
            
            if (response.ok) {
                const introspectionData = await response.json();
                const tableNames = Object.keys(introspectionData.definitions || {});
                
                for (const tableName of tableNames) {
                    await getTableSchema(tableName, schemaData);
                }
            }
        } else {
            for (const table of tables || []) {
                await getTableSchema(table.table_name, schemaData);
            }
        }

        // 2. Get storage buckets
        console.log('🪣 Getting storage buckets...');
        await getStorageBuckets(schemaData);

        // 3. Get triggers
        console.log('⚡ Getting triggers...');
        await getTriggers(schemaData);

        // 4. Get RLS policies
        console.log('🔒 Getting RLS policies...');
        await getRLSPolicies(schemaData);

        // 5. Get custom types
        console.log('🏷️ Getting custom types...');
        await getCustomTypes(schemaData);

        // 6. Get views
        console.log('👁️ Getting views...');
        await getViews(schemaData);

        // 7. Try to get edge functions info
        console.log('🔄 Getting edge functions...');
        await getEdgeFunctions(schemaData);

        // Update metadata
        schemaData.metadata.totalTables = Object.keys(schemaData.tables).length;
        schemaData.metadata.totalStorageBuckets = Object.keys(schemaData.storageBuckets).length;
        schemaData.metadata.totalTriggers = Object.keys(schemaData.triggers).length;
        schemaData.metadata.totalPolicies = Object.keys(schemaData.policies).length;

        // Save to file
        const outputPath = path.join(process.cwd(), 'DATABASE_SCHEMA_REFERENCE.json');
        fs.writeFileSync(outputPath, JSON.stringify(schemaData, null, 2));
        
        console.log(`\n✅ Complete database schema extracted!`);
        console.log(`📁 Saved to: ${outputPath}`);
        console.log(`📊 Summary:`);
        console.log(`   - Tables: ${schemaData.metadata.totalTables}`);
        console.log(`   - Storage Buckets: ${schemaData.metadata.totalStorageBuckets}`);
        console.log(`   - Triggers: ${schemaData.metadata.totalTriggers}`);
        console.log(`   - RLS Policies: ${schemaData.metadata.totalPolicies}`);
        console.log(`   - Custom Types: ${Object.keys(schemaData.customTypes).length}`);
        console.log(`   - Views: ${Object.keys(schemaData.views).length}`);

        // Also create a markdown version
        await createMarkdownReference(schemaData);

    } catch (error) {
        console.error('❌ Error extracting schema:', error);
    }
}

async function getTableSchema(tableName, schemaData) {
    try {
        console.log(`  📋 Processing table: ${tableName}`);
        
        // Get columns
        const { data: columns, error: columnsError } = await supabase
            .rpc('get_table_columns', { table_name: tableName })
            .catch(async () => {
                // Fallback: Query information_schema
                const { data, error } = await supabase
                    .from('information_schema.columns')
                    .select('*')
                    .eq('table_name', tableName)
                    .eq('table_schema', 'public');
                return { data, error };
            });

        // Get constraints
        const { data: constraints } = await supabase
            .from('information_schema.table_constraints')
            .select('*')
            .eq('table_name', tableName)
            .eq('table_schema', 'public')
            .catch(() => ({ data: [] }));

        // Get foreign keys
        const { data: foreignKeys } = await supabase
            .from('information_schema.key_column_usage')
            .select('*')
            .eq('table_name', tableName)
            .eq('table_schema', 'public')
            .catch(() => ({ data: [] }));

        schemaData.tables[tableName] = {
            columns: columns || [],
            constraints: constraints || [],
            foreignKeys: foreignKeys || [],
            lastUpdated: new Date().toISOString()
        };

    } catch (error) {
        console.log(`    ⚠️ Error getting schema for ${tableName}:`, error.message);
        schemaData.tables[tableName] = {
            error: error.message,
            lastUpdated: new Date().toISOString()
        };
    }
}

async function getStorageBuckets(schemaData) {
    try {
        const { data: buckets, error } = await supabase.storage.listBuckets();
        
        if (error) throw error;

        for (const bucket of buckets || []) {
            console.log(`  🪣 Processing bucket: ${bucket.name}`);
            
            // Get bucket details and policies
            const { data: files } = await supabase.storage
                .from(bucket.name)
                .list('', { limit: 1 })
                .catch(() => ({ data: [] }));

            schemaData.storageBuckets[bucket.name] = {
                ...bucket,
                sampleFiles: files?.slice(0, 5) || [],
                lastUpdated: new Date().toISOString()
            };
        }
    } catch (error) {
        console.log(`    ⚠️ Error getting storage buckets:`, error.message);
    }
}

async function getTriggers(schemaData) {
    try {
        const { data: triggers } = await supabase
            .from('information_schema.triggers')
            .select('*')
            .eq('trigger_schema', 'public')
            .catch(() => ({ data: [] }));

        for (const trigger of triggers || []) {
            console.log(`  ⚡ Processing trigger: ${trigger.trigger_name}`);
            schemaData.triggers[trigger.trigger_name] = trigger;
        }

        // Also try to get trigger functions
        const { data: routines } = await supabase
            .from('information_schema.routines')
            .select('*')
            .eq('routine_schema', 'public')
            .eq('routine_type', 'FUNCTION')
            .catch(() => ({ data: [] }));

        schemaData.triggerFunctions = {};
        for (const routine of routines || []) {
            if (routine.routine_name.includes('trigger') || routine.routine_name.includes('handle_')) {
                console.log(`  🔧 Processing trigger function: ${routine.routine_name}`);
                schemaData.triggerFunctions[routine.routine_name] = routine;
            }
        }

    } catch (error) {
        console.log(`    ⚠️ Error getting triggers:`, error.message);
    }
}

async function getRLSPolicies(schemaData) {
    try {
        const { data: policies } = await supabase
            .from('pg_policies')
            .select('*')
            .catch(() => ({ data: [] }));

        for (const policy of policies || []) {
            console.log(`  🔒 Processing policy: ${policy.policyname} on ${policy.tablename}`);
            
            const key = `${policy.tablename}.${policy.policyname}`;
            schemaData.policies[key] = policy;
        }
    } catch (error) {
        console.log(`    ⚠️ Error getting RLS policies:`, error.message);
    }
}

async function getCustomTypes(schemaData) {
    try {
        const { data: types } = await supabase
            .from('information_schema.user_defined_types')
            .select('*')
            .eq('user_defined_type_schema', 'public')
            .catch(() => ({ data: [] }));

        for (const type of types || []) {
            console.log(`  🏷️ Processing type: ${type.user_defined_type_name}`);
            schemaData.customTypes[type.user_defined_type_name] = type;
        }
    } catch (error) {
        console.log(`    ⚠️ Error getting custom types:`, error.message);
    }
}

async function getViews(schemaData) {
    try {
        const { data: views } = await supabase
            .from('information_schema.views')
            .select('*')
            .eq('table_schema', 'public')
            .catch(() => ({ data: [] }));

        for (const view of views || []) {
            console.log(`  👁️ Processing view: ${view.table_name}`);
            schemaData.views[view.table_name] = view;
        }
    } catch (error) {
        console.log(`    ⚠️ Error getting views:`, error.message);
    }
}

async function getEdgeFunctions(schemaData) {
    try {
        // Edge functions are not accessible via SQL, but we can check the local functions directory
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
                    path: functionPath,
                    hasIndex: fs.existsSync(indexPath)
                };

                if (functionInfo.hasIndex) {
                    try {
                        const indexContent = fs.readFileSync(indexPath, 'utf8');
                        functionInfo.preview = indexContent.substring(0, 500) + '...';
                    } catch (err) {
                        functionInfo.error = 'Could not read index.ts';
                    }
                }

                schemaData.edgeFunctions.push(functionInfo);
            }
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

- **Total Tables**: ${schemaData.metadata.totalTables}
- **Storage Buckets**: ${schemaData.metadata.totalStorageBuckets}
- **Triggers**: ${schemaData.metadata.totalTriggers}
- **RLS Policies**: ${schemaData.metadata.totalPolicies}
- **Custom Types**: ${Object.keys(schemaData.customTypes).length}
- **Views**: ${Object.keys(schemaData.views).length}
- **Edge Functions**: ${schemaData.edgeFunctions.length}

## Tables

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

    Object.entries(tableGroups).forEach(([prefix, tables]) => {
        markdown += `### ${prefix.toUpperCase()} Tables\n\n`;
        tables.forEach(tableName => {
            markdown += `#### ${tableName}\n\n`;
            const table = schemaData.tables[tableName];
            
            if (table.error) {
                markdown += `*Error: ${table.error}*\n\n`;
                return;
            }

            if (table.columns?.length > 0) {
                markdown += `| Column | Type | Nullable | Default |\n`;
                markdown += `|--------|------|----------|----------|\n`;
                table.columns.forEach(col => {
                    markdown += `| ${col.column_name || col.name} | ${col.data_type || col.type} | ${col.is_nullable || col.nullable} | ${col.column_default || col.default || ''} |\n`;
                });
                markdown += `\n`;
            }
        });
    });

    // Storage Buckets
    markdown += `## Storage Buckets\n\n`;
    Object.entries(schemaData.storageBuckets).forEach(([bucketName, bucket]) => {
        markdown += `### ${bucketName}\n\n`;
        markdown += `- **ID**: ${bucket.id}\n`;
        markdown += `- **Public**: ${bucket.public}\n`;
        markdown += `- **Created**: ${bucket.created_at}\n`;
        markdown += `- **Updated**: ${bucket.updated_at}\n\n`;
    });

    // Edge Functions
    if (schemaData.edgeFunctions.length > 0) {
        markdown += `## Edge Functions\n\n`;
        schemaData.edgeFunctions.forEach(func => {
            markdown += `### ${func.name}\n\n`;
            markdown += `- **Path**: ${func.path}\n`;
            markdown += `- **Has Index**: ${func.hasIndex}\n`;
            if (func.preview) {
                markdown += `\n**Preview:**\n\`\`\`typescript\n${func.preview}\n\`\`\`\n\n`;
            }
        });
    }

    fs.writeFileSync(mdPath, markdown);
    console.log(`📄 Markdown reference saved to: ${mdPath}`);
}

// Run the extraction
extractCompleteSchema();