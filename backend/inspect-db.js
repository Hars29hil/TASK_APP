import dotenv from "dotenv";
import { createClient } from "@supabase/supabase-js";

dotenv.config({ path: '../.env' });

const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_ROLE_KEY
);

async function inspectDb() {
    // 1. Fetch some task steps to see their status
    const { data: steps, error } = await supabase
        .from('task_steps')
        .select('*')
        .limit(10);
    
    if (error) {
        console.error("Error fetching steps:", error);
    } else {
        console.log("Existing steps in database:");
        steps.forEach(s => {
            console.log(`Step ID: ${s.id}, Title: ${s.step_title}, Status: ${s.status}`);
        });
    }
}

inspectDb();
