import dotenv from "dotenv";
import { createClient } from "@supabase/supabase-js";

dotenv.config({ path: '../.env' });

const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_ROLE_KEY
);

async function inspectChats() {
    console.log("--- TASK GROUP MESSAGES ---");
    const { data: groupMsgs, error: groupErr } = await supabase
        .from('task_group_messages')
        .select('*, profiles:sender_id(email, full_name)')
        .limit(10);
    
    if (groupErr) {
        console.error("Error fetching group messages:", groupErr);
    } else {
        console.log(`Total group messages: ${groupMsgs.length}`);
        groupMsgs.forEach(m => {
            console.log(`[Task ID: ${m.task_id}] [Sender: ${m.profiles?.email || m.sender_id}] Content: ${m.content} (${m.created_at})`);
        });
    }

    console.log("\n--- DIRECT MESSAGES ---");
    const { data: dms, error: dmErr } = await supabase
        .from('messages')
        .select('*, sender:sender_id(email), receiver:receiver_id(email)')
        .limit(10);
        
    if (dmErr) {
        console.error("Error fetching DMs:", dmErr);
    } else {
        console.log(`Total DMs: ${dms.length}`);
        dms.forEach(m => {
            console.log(`[Sender: ${m.sender?.email}] [Receiver: ${m.receiver?.email}] Content: ${m.content} (${m.created_at})`);
        });
    }
}

inspectChats();
