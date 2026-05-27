import dotenv from "dotenv";
import { createClient } from "@supabase/supabase-js";

dotenv.config({ path: '../.env' });

const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_ROLE_KEY
);

async function inspectTables() {
    const url = `${process.env.SUPABASE_URL}/rest/v1/`;
    const response = await fetch(url, {
        headers: {
            'apikey': process.env.SUPABASE_SERVICE_ROLE_KEY,
            'Authorization': `Bearer ${process.env.SUPABASE_SERVICE_ROLE_KEY}`
        }
    });
    
    if (!response.ok) {
        console.error("Failed to fetch schema:", response.statusText);
        process.exit(1);
    }
    
    const schema = await response.json();
    console.log("--- Definitions ---");
    if (schema.definitions) {
        for (const [tableName, tableDef] of Object.entries(schema.definitions)) {
            if (['tasks', 'task_steps', 'deadline_extensions'].includes(tableName)) {
                console.log(`Table: ${tableName}`);
                if (tableDef.properties) {
                    for (const [colName, colDef] of Object.entries(tableDef.properties)) {
                        console.log(`  - ${colName}: ${colDef.type} (${colDef.format || ''})`);
                    }
                }
            }
        }
    }
}

inspectTables();
