import dotenv from "dotenv";
import { createClient } from "@supabase/supabase-js";

dotenv.config({ path: '../.env' });

const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_ROLE_KEY
);

async function fixRLS() {
    const sql = `
      DROP POLICY IF EXISTS "messages_select" ON messages;
      DROP POLICY IF EXISTS "messages_insert" ON messages;
      CREATE POLICY "messages_select" ON messages FOR SELECT USING (true);
      CREATE POLICY "messages_insert" ON messages FOR INSERT WITH CHECK (true);
      
      DROP POLICY IF EXISTS "tgm_select" ON task_group_messages;
      DROP POLICY IF EXISTS "tgm_insert" ON task_group_messages;
      CREATE POLICY "tgm_select" ON task_group_messages FOR SELECT USING (true);
      CREATE POLICY "tgm_insert" ON task_group_messages FOR INSERT WITH CHECK (true);
    `;
    const { error } = await supabase.rpc('exec_sql', { sql_query: sql });
    if (error) {
        console.error("Error updating RLS:", error);
    } else {
        console.log("RLS updated successfully.");
    }
}

fixRLS();
