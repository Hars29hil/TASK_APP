import dotenv from "dotenv";
import { createClient } from "@supabase/supabase-js";

dotenv.config({ path: '../.env' });

const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_ROLE_KEY
);

async function inspectMembers() {
    console.log("--- PROFILES ---");
    const { data: profiles, error: pErr } = await supabase
        .from('profiles')
        .select('id, email, full_name');
        
    if (pErr) console.error(pErr);
    else {
        profiles.forEach(p => console.log(`User ID: ${p.id} | Email: ${p.email} | Name: ${p.full_name}`));
    }

    console.log("\n--- TASK MEMBERS ---");
    const { data: members, error: mErr } = await supabase
        .from('task_members')
        .select('*, tasks(title), profiles(email)');
        
    if (mErr) console.error(mErr);
    else {
        members.forEach(m => {
            console.log(`Task: ${m.tasks?.title} | User: ${m.profiles?.email || m.user_id} | Role: ${m.role}`);
        });
    }
}

inspectMembers();
