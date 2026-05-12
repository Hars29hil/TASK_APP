import { createClient } from '@supabase/supabase-js';
import dotenv from "dotenv";

// Load environment variables
dotenv.config({ path: '../.env' });

const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_ROLE_KEY
);

async function deleteAllChats() {
    console.log("🧹 Starting to clear all chat messages...");

    try {
        const { data, error } = await supabase
            .from('messages')
            .delete()
            .gt('id', 0); // Use .gt('id', 0) for integer IDs to target all rows

        if (error) {
            console.error("❌ Error deleting messages:", error.message);
            return;
        }

        console.log("✅ All chat messages have been deleted successfully.");
    } catch (err) {
        console.error("CRITICAL ERROR:", err);
    } finally {
        process.exit(0);
    }
}

deleteAllChats();
