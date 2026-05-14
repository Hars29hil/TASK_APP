import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
import path from 'path';

// Load env from parent dir
dotenv.config({ path: '../.env' });

const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_ROLE_KEY
);

async function createDemoTask() {
    console.log("🚀 Starting Demo Task Creation...");

    try {
        // 1. Get all users
        const { data: profiles, error: pError } = await supabase
            .from('profiles')
            .select('id, full_name, email');

        if (pError || !profiles || profiles.length === 0) {
            console.error("❌ Error fetching profiles:", pError || "No profiles found");
            return;
        }

        console.log(`✅ Found ${profiles.length} users.`);

        // Pick an admin (the first user found)
        const creator = profiles[0];
        
        // Define steps and rotate users through them
        const demoSteps = [
            { title: "UI/UX Design Phase", description: "Design the high-fidelity mockups for the app." },
            { title: "Frontend Development", description: "Build the Flutter screens and navigation." },
            { title: "Backend Integration", description: "Connect APIs and setup database sync." },
            { title: "QA & Bug Fixing", description: "Test all features and fix reported issues." },
            { title: "App Store Deployment", description: "Submit the app to Play Store and App Store." }
        ];

        // Assign users to steps in a loop
        const stepsWithUsers = demoSteps.map((step, index) => {
            const assignedUser = profiles[index % profiles.length];
            return {
                title: step.title,
                assigned_users: [assignedUser.id]
            };
        });

        // 2. Prepare Payload for our API
        const payload = {
            title: "Project: Global App Launch 2026",
            description: "This is a full-cycle development task with 5 dependent stages. Completing one stage will automatically notify the next person in line.",
            priority: "urgent",
            deadline: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString(), // 7 days from now
            created_by: creator.id,
            leader_id: profiles[1] ? profiles[1].id : creator.id, // Second user is leader
            members: profiles.map(u => u.id), // Add everyone to the task
            steps: stepsWithUsers
        };

        console.log("📦 Payload prepared. Sending to local server...");

        // 3. Send to our Workflow API
        const response = await fetch('http://localhost:5000/tasks', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });

        const result = await response.json();

        if (result.success) {
            console.log("\n✨ SUCCESS! Demo Task Created.");
            console.log("===============================");
            console.log(`Task ID: ${result.task.id}`);
            console.log(`Title: ${payload.title}`);
            console.log(`Active Step: ${result.task.task_steps[0].step_title}`);
            console.log(`Assigned To: ${profiles[0].full_name}`);
            console.log("===============================");
            console.log("🔔 Notifications have been sent to all users via FCM.");
            console.log("Check your Flutter app to see the animated timeline!");
        } else {
            console.error("❌ Failed to create task:", result.message);
        }

    } catch (err) {
        console.error("💥 Script Error:", err.message);
        console.log("\n💡 Make sure your backend server is running (node server.js) on port 5000.");
    }
}

createDemoTask();
