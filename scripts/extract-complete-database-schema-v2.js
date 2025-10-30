import { createClient } from '@supabase/supabase-js';
import fs from 'fs';
import path from 'path';

// Load environment variables
import dotenv from 'dotenv';
dotenv.config({ path: '../frontend/.env' });

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
        views: {}
    };

    try {
        // 1. Get all tables using PostgREST introspection
        console.log('📊 Getting tables using PostgREST...');
        const response = await fetch(`${supabaseUrl}/rest/v1/`, {
            headers: {
                'Authorization': `Bearer ${supabaseServiceKey}`,
                'apikey': supabaseServiceKey,
                'Accept': 'application/vnd.pgrst.object+json'
            }
        });
        
        if (!response.ok) {
            throw new Error(`PostgREST request failed: ${response.statusText}`);
        }

        const introspectionData = await response.json();
        const tableNames = Object.keys(introspectionData.definitions || {});
        
        console.log(`Found ${tableNames.length} tables`);

        // 2. Get detailed schema for each table
        for (const tableName of tableNames) {
            await getTableSchema(tableName, schemaData);
        }

        // 3. Get storage buckets
        console.log('\n🪣 Getting storage buckets...');
        await getStorageBuckets(schemaData);

        // 4. Get triggers using raw SQL
        console.log('⚡ Getting triggers...');
        await getTriggers(schemaData);

        // 5. Get RLS policies using raw SQL
        console.log('🔒 Getting RLS policies...');
        await getRLSPolicies(schemaData);

        // 6. Get custom types
        console.log('🏷️ Getting custom types...');
        await getCustomTypes(schemaData);

        // 7. Get views
        console.log('👁️ Getting views...');
        await getViews(schemaData);

        // 8. Get edge functions from file system
        console.log('🔄 Getting edge functions...');
        await getEdgeFunctions(schemaData);

        // Update metadata
        schemaData.metadata.totalTables = Object.keys(schemaData.tables).length;
        schemaData.metadata.totalStorageBuckets = Object.keys(schemaData.storageBuckets).length;
        schemaData.metadata.totalTriggers = schemaData.triggers.length;
        schemaData.metadata.totalPolicies = schemaData.policies.length;

        // Save to file
        const outputPath = path.join(process.cwd(), '..', 'DATABASE_SCHEMA_REFERENCE.json');
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
        console.log(`   - Edge Functions: ${schemaData.edgeFunctions.length}`);

        // Also create a markdown version
        await createMarkdownReference(schemaData);

    } catch (error) {
        console.error('❌ Error extracting schema:', error);
    }
}

async function getTableSchema(tableName, schemaData) {
    try {
        console.log(`  📋 Processing table: ${tableName}`);
        
        // Get columns using SQL query
        const { data: columns, error: columnsError } = await supabase
            .rpc('exec_sql', { 
                sql: `
                    SELECT 
                        column_name,
                        data_type,
                        is_nullable,
                        column_default,
                        character_maximum_length,
                        numeric_precision,
                        numeric_scale
                    FROM information_schema.columns 
                    WHERE table_name = '${tableName}' 
                    AND table_schema = 'public'
                    ORDER BY ordinal_position;
                `
            });

        if (columnsError) {
            // Fallback: try direct query
            const { data: fallbackColumns } = await supabase
                .from(tableName)
                .select('*')
                .limit(0);
            
            schemaData.tables[tableName] = {
                columns: 'Schema not accessible via SQL',
                note: 'Table exists but schema details require direct database access',
                lastUpdated: new Date().toISOString()
            };
        } else {
            // Get constraints
            const { data: constraints } = await supabase
                .rpc('exec_sql', {
                    sql: `
                        SELECT 
                            tc.constraint_name,
                            tc.constraint_type,
                            kcu.column_name,
                            ccu.table_name AS foreign_table_name,
                            ccu.column_name AS foreign_column_name
                        FROM information_schema.table_constraints tc
                        LEFT JOIN information_schema.key_column_usage kcu
                            ON tc.constraint_name = kcu.constraint_name
                            AND tc.table_schema = kcu.table_schema
                        LEFT JOIN information_schema.constraint_column_usage ccu
                            ON ccu.constraint_name = tc.constraint_name
                            AND ccu.table_schema = tc.table_schema
                        WHERE tc.table_name = '${tableName}' 
                        AND tc.table_schema = 'public';
                    `
                });

            schemaData.tables[tableName] = {
                columns: columns || [],
                constraints: constraints || [],
                lastUpdated: new Date().toISOString()
            };
        }

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

            schemaData.storageBuckets[bucket.name] = {
                ...bucket,
                sampleFiles: files || [],
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
            .rpc('exec_sql', {
                sql: `
                    SELECT 
                        trigger_name,
                        event_manipulation,
                        event_object_table,
                        action_statement,
                        action_timing,
                        action_orientation
                    FROM information_schema.triggers 
                    WHERE trigger_schema = 'public';
                `
            });

        if (triggers) {
            for (const trigger of triggers) {
                console.log(`  ⚡ Found trigger: ${trigger.trigger_name}`);
                schemaData.triggers.push(trigger);
            }
        }

        // Get trigger functions
        const { data: functions } = await supabase
            .rpc('exec_sql', {
                sql: `
                    SELECT 
                        routine_name,
                        routine_type,
                        data_type,
                        routine_definition
                    FROM information_schema.routines 
                    WHERE routine_schema = 'public' 
                    AND routine_type = 'FUNCTION';
                `
            });

        if (functions) {
            schemaData.triggerFunctions = functions.filter(f => 
                f.routine_name.includes('trigger') || 
                f.routine_name.includes('handle_') ||
                f.routine_name.includes('update_')
            );
        }

    } catch (error) {
        console.log(`    ⚠️ Error getting triggers:`, error.message);
    }
}

async function getRLSPolicies(schemaData) {
    try {
        const { data: policies } = await supabase
            .rpc('exec_sql', {
                sql: `
                    SELECT 
                        schemaname,
                        tablename,
                        policyname,
                        permissive,
                        roles,
                        cmd,
                        qual,
                        with_check
                    FROM pg_policies;
                `
            });

        if (policies) {
            for (const policy of policies) {
                console.log(`  🔒 Found policy: ${policy.policyname} on ${policy.tablename}`);
                schemaData.policies.push(policy);
            }
        }
    } catch (error) {
        console.log(`    ⚠️ Error getting RLS policies:`, error.message);
    }
}

async function getCustomTypes(schemaData) {
    try {
        const { data: types } = await supabase
            .rpc('exec_sql', {
                sql: `
                    SELECT 
                        user_defined_type_name,
                        user_defined_type_schema
                    FROM information_schema.user_defined_types 
                    WHERE user_defined_type_schema = 'public';
                `
            });

        if (types) {
            for (const type of types) {
                console.log(`  🏷️ Found type: ${type.user_defined_type_name}`);
                schemaData.customTypes[type.user_defined_type_name] = type;
            }
        }
    } catch (error) {
        console.log(`    ⚠️ Error getting custom types:`, error.message);
    }
}

async function getViews(schemaData) {
    try {
        const { data: views } = await supabase
            .rpc('exec_sql', {
                sql: `
                    SELECT 
                        table_name,
                        view_definition
                    FROM information_schema.views 
                    WHERE table_schema = 'public';
                `
            });

        if (views) {
            for (const view of views) {
                console.log(`  👁️ Found view: ${view.table_name}`);
                schemaData.views[view.table_name] = view;
            }
        }
    } catch (error) {
        console.log(`    ⚠️ Error getting views:`, error.message);
    }
}

async function getEdgeFunctions(schemaData) {
    try {
        // Edge functions are in the supabase/functions directory
        const functionsDir = path.join(process.cwd(), '..', 'supabase', 'functions');
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
                        
                        // Extract basic info from the function
                        const lines = indexContent.split('\n');
                        const description = lines.find(line => line.includes('//') && line.toLowerCase().includes('description'));
                        if (description) {
                            functionInfo.description = description.replace(/\/\/\s*/, '').trim();
                        }
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
    const mdPath = path.join(process.cwd(), '..', 'DATABASE_SCHEMA_REFERENCE.md');
    
    let markdown = `# Aqura Database Schema Reference

*Generated on ${schemaData.metadata.extractedAt}*

## Overview

- **Database URL**: ${schemaData.metadata.supabaseUrl}
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

    Object.entries(tableGroups).sort().forEach(([prefix, tables]) => {
        markdown += `### ${prefix.toUpperCase()} Tables (${tables.length} tables)\n\n`;
        tables.sort().forEach(tableName => {
            markdown += `#### \`${tableName}\`\n\n`;
            const table = schemaData.tables[tableName];
            
            if (table.error) {
                markdown += `*Error: ${table.error}*\n\n`;
                return;
            }

            if (table.columns && Array.isArray(table.columns) && table.columns.length > 0) {
                markdown += `| Column | Type | Nullable | Default |\n`;
                markdown += `|--------|------|----------|----------|\n`;
                table.columns.forEach(col => {
                    const colName = col.column_name || col.name || 'Unknown';
                    const colType = col.data_type || col.type || 'Unknown';
                    const nullable = col.is_nullable || col.nullable || 'Unknown';
                    const defaultVal = col.column_default || col.default || '';
                    markdown += `| ${colName} | ${colType} | ${nullable} | ${defaultVal} |\n`;
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
            } else if (typeof table.columns === 'string') {
                markdown += `*${table.columns}*\n\n`;
            }
        });
    });

    // Storage Buckets
    if (Object.keys(schemaData.storageBuckets).length > 0) {
        markdown += `## Storage Buckets\n\n`;
        Object.entries(schemaData.storageBuckets).forEach(([bucketName, bucket]) => {
            markdown += `### \`${bucketName}\`\n\n`;
            markdown += `- **ID**: ${bucket.id}\n`;
            markdown += `- **Public**: ${bucket.public}\n`;
            markdown += `- **Created**: ${bucket.created_at}\n`;
            markdown += `- **Updated**: ${bucket.updated_at}\n`;
            if (bucket.sampleFiles && bucket.sampleFiles.length > 0) {
                markdown += `- **Sample Files**: ${bucket.sampleFiles.map(f => f.name).join(', ')}\n`;
            }
            markdown += `\n`;
        });
    }

    // Triggers
    if (schemaData.triggers.length > 0) {
        markdown += `## Database Triggers\n\n`;
        schemaData.triggers.forEach(trigger => {
            markdown += `### \`${trigger.trigger_name}\`\n\n`;
            markdown += `- **Table**: ${trigger.event_object_table}\n`;
            markdown += `- **Event**: ${trigger.event_manipulation}\n`;
            markdown += `- **Timing**: ${trigger.action_timing}\n`;
            markdown += `- **Statement**: ${trigger.action_statement}\n\n`;
        });
    }

    // RLS Policies
    if (schemaData.policies.length > 0) {
        markdown += `## Row Level Security Policies\n\n`;
        const policiesByTable = {};
        schemaData.policies.forEach(policy => {
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
                if (policy.qual) markdown += `- **Condition**: \`${policy.qual}\`\n`;
                if (policy.with_check) markdown += `- **With Check**: \`${policy.with_check}\`\n`;
                markdown += `\n`;
            });
        });
    }

    // Edge Functions
    if (schemaData.edgeFunctions.length > 0) {
        markdown += `## Edge Functions\n\n`;
        schemaData.edgeFunctions.forEach(func => {
            markdown += `### \`${func.name}\`\n\n`;
            markdown += `- **Path**: ${func.path}\n`;
            markdown += `- **Has Index**: ${func.hasIndex}\n`;
            if (func.description) {
                markdown += `- **Description**: ${func.description}\n`;
            }
            if (func.preview) {
                markdown += `\n**Code Preview:**\n\`\`\`typescript\n${func.preview}\n\`\`\`\n\n`;
            }
        });
    }

    // Custom Types
    if (Object.keys(schemaData.customTypes).length > 0) {
        markdown += `## Custom Types\n\n`;
        Object.entries(schemaData.customTypes).forEach(([typeName, typeInfo]) => {
            markdown += `### \`${typeName}\`\n\n`;
            markdown += `- **Schema**: ${typeInfo.user_defined_type_schema}\n\n`;
        });
    }

    // Views
    if (Object.keys(schemaData.views).length > 0) {
        markdown += `## Database Views\n\n`;
        Object.entries(schemaData.views).forEach(([viewName, viewInfo]) => {
            markdown += `### \`${viewName}\`\n\n`;
            if (viewInfo.view_definition) {
                markdown += `\`\`\`sql\n${viewInfo.view_definition}\n\`\`\`\n\n`;
            }
        });
    }

    fs.writeFileSync(mdPath, markdown);
    console.log(`📄 Markdown reference saved to: ${mdPath}`);
}

// Run the extraction
extractCompleteSchema();