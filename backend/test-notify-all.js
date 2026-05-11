import { createClient } from '@supabase/supabase-js';
import { sendPushNotification } from "./firebase.js";
import dotenv from "dotenv";

// Load environment variables
dotenv.config({ path: '../.env' });

const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_ROLE_KEY
);

async function notifyAllUsers() {
    console.log("🚀 Starting Global Test Notification...");

    try {
        // 1. Fetch all profiles with a token
        const { data: profiles, error } = await supabase
            .from('profiles')
            .select('id, full_name, fcm_token')
            .not('fcm_token', 'is', null);

        if (error) {
            console.error("❌ Error fetching profiles:", error);
            return;
        }

        if (!profiles || profiles.length === 0) {
            console.log("⚠️ No users found with FCM tokens in the database.");
            return;
        }

        console.log(`Found ${profiles.length} users with FCM tokens.`);

        // 2. Send to each user
        for (const profile of profiles) {
            try {
                console.log(`Sending to: ${profile.full_name} (${profile.fcm_token.substring(0, 10)}...)`);
                await sendPushNotification(
                    profile.fcm_token,
                    "Global Test Notification",
                    `Hi ${profile.full_name}, this is a test from the server!`,
                    { type: "test_all", sent_at: new Date().toISOString() }
                );
                console.log(`✅ Success: Sent to ${profile.full_name}`);
            } catch (err) {
                console.error(`❌ Failed: Could not send to ${profile.full_name}:`, err.message);
            }
        }

        console.log("\n🏁 Global notification process finished.");
    } catch (err) {
        console.error("CRITICAL ERROR:", err);
    } finally {
        process.exit(0);
    }
}

notifyAllUsers();
