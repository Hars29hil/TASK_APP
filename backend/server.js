import express from "express";
import cors from "cors";
import dotenv from "dotenv";
import nodemailer from "nodemailer";
import { createClient } from '@supabase/supabase-js';
import { sendPushNotification } from "./firebase.js";

// Load environment variables (try current folder first, then parent folder as fallback)
dotenv.config();
dotenv.config({ path: '../.env' });

// ======================================
// CONSOLE LOG INTERCEPTOR
// ======================================
const logBuffer = [];
const MAX_LOGS = 1000;
const bootTime = new Date();

const originalLog = console.log;
const originalError = console.error;
const originalWarn = console.warn;

function formatLogMessage(args) {
  return args.map(arg => {
    if (arg instanceof Error) {
      return arg.stack || arg.message;
    }
    if (typeof arg === 'object') {
      try {
        return JSON.stringify(arg, null, 2);
      } catch (e) {
        return String(arg);
      }
    }
    return String(arg);
  }).join(' ');
}

function addLogToBuffer(type, args) {
  const timestamp = new Date().toISOString();
  const message = formatLogMessage(args);
  logBuffer.push({ timestamp, type, message });
  if (logBuffer.length > MAX_LOGS) {
    logBuffer.shift();
  }
}

console.log = (...args) => {
  originalLog.apply(console, args);
  addLogToBuffer('info', args);
};

console.error = (...args) => {
  originalError.apply(console, args);
  addLogToBuffer('error', args);
};

console.warn = (...args) => {
  originalWarn.apply(console, args);
  addLogToBuffer('warn', args);
};

const app = express();

app.use(cors({
  origin: (origin, callback) => {
    // Allow all origins in development
    callback(null, true);
  },
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With', 'Accept'],
  credentials: true
}));
app.use(express.json());

// ======================================
// SUPABASE CONFIG
// ======================================
if (!process.env.SUPABASE_URL || !process.env.SUPABASE_SERVICE_ROLE_KEY) {
  console.warn("⚠️ Warning: SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY environment variables are not set.");
}
const supabase = (process.env.SUPABASE_URL && process.env.SUPABASE_SERVICE_ROLE_KEY)
  ? createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY)
  : null;

// ======================================
// TEMP OTP STORAGE
// (Use DB/Redis in production)
// ======================================
const otpStore = {};

// ======================================
// NODEMAILER CONFIG
// ======================================
const transporter = nodemailer.createTransport(
  process.env.SMTP_HOST
    ? {
        host: process.env.SMTP_HOST,
        port: parseInt(process.env.SMTP_PORT || "2525"),
        secure: process.env.SMTP_SECURE === "true",
        auth: {
          user: process.env.SMTP_USER,
          pass: process.env.SMTP_PASS,
        },
      }
    : {
        service: "gmail",
        auth: {
          user: process.env.EMAIL_USER,
          pass: process.env.EMAIL_PASS,
        },
      }
);

// ======================================
// GENERATE OTP
// ======================================
function generateOTP() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

// ======================================
// HOME ROUTE
// ======================================
app.get("/", (req, res) => {
    res.send("Backend Server is running successfully!");
});

// ======================================
// WEB LOGS ENDPOINTS & UI
// ======================================
app.get("/api/logs", (req, res) => {
  res.json({
    success: true,
    uptime: Math.floor((new Date() - bootTime) / 1000), // in seconds
    count: logBuffer.length,
    logs: logBuffer
  });
});

app.delete("/api/logs", (req, res) => {
  logBuffer.length = 0;
  console.log("🧹 Logs buffer cleared via web interface.");
  res.json({ success: true, message: "Logs cleared successfully" });
});

app.get("/logs", (req, res) => {
  res.send(HTML_LOGS_PAGE);
});

// ======================================
// SEND OTP API
// ======================================
app.post("/send-otp", async (req, res) => {
  try {
    const { email } = req.body;
    console.log('Received /send-otp request for:', email);

    // validation
    if (!email) {
      return res.status(400).json({
        success: false,
        message: "Email is required",
      });
    }

    // generate otp
    const otp = generateOTP();

    // save otp temporarily
    otpStore[email] = {
      otp,
      expiresAt: Date.now() + 5 * 60 * 1000, // 5 min
    };

    // mail options
    const mailOptions = {
      from: process.env.SMTP_FROM || process.env.EMAIL_USER,
      to: email,
      subject: "Your OTP Code",
      html: `
        <h2>OTP Verification</h2>
        <p>Your OTP is:</p>
        <h1>${otp}</h1>
        <p>Valid for 5 minutes</p>
      `,
    };

    // send mail
    console.log('Sending email...');
    await transporter.sendMail(mailOptions);
    console.log('OTP sent successfully to', email);

    res.status(200).json({
      success: true,
      message: "OTP sent successfully",
    });
  } catch (error) {
    console.error('Detailed Error:', error);
    res.status(500).json({
      success: false,
      message: "Failed to send OTP",
    });
  }
});

// ======================================
// VERIFY OTP & REGISTER API
// ======================================
app.post("/verify-otp", async (req, res) => {
  try {
    const { email, otp, fullName, password } = req.body;

    // check email exists
    if (!otpStore[email]) {
      return res.status(400).json({
        success: false,
        message: "OTP not found",
      });
    }

    const storedOTP = otpStore[email];

    // check expiry
    if (Date.now() > storedOTP.expiresAt) {
      delete otpStore[email];
      return res.status(400).json({
        success: false,
        message: "OTP expired",
      });
    }

    // verify otp
    if (storedOTP.otp !== otp) {
      return res.status(400).json({
        success: false,
        message: "Invalid OTP",
      });
    }

    // OTP VERIFIED - Now Register/Confirm in Supabase Auth
    console.log('OTP verified. Ensuring user exists in Supabase Auth...');
    
    let userId;
    
    // 1. Try to create the user
    const { data: authData, error: authError } = await supabase.auth.admin.createUser({
        email: email,
        password: password,
        email_confirm: true,
        user_metadata: { full_name: fullName }
    });

    if (authError) {
        // If user already exists, we find them and force-update them
        if (authError.message.toLowerCase().includes('already registered') || authError.message.toLowerCase().includes('already exists')) {
            console.log('User exists. Attempting to force-confirm account...');
            
            const { data: listData, error: listError } = await supabase.auth.admin.listUsers();
            if (listError) throw listError;

            const existingUser = listData.users.find(u => u.email === email);
            
            if (existingUser) {
                userId = existingUser.id;
                const { error: updateError } = await supabase.auth.admin.updateUserById(userId, {
                    password: password,
                    email_confirm: true
                });
                if (updateError) throw updateError;
                console.log('User force-confirmed successfully.');
            } else {
                throw new Error("User reported as existing but not found in list.");
            }
        } else {
            throw authError;
        }
    } else {
        userId = authData.user.id;
        console.log('New user created and confirmed.');
    }

    // 2. Create/Update in public.profiles
    const { data: profileData, error: profileError } = await supabase
        .from('profiles')
        .upsert([{ 
            id: userId, 
            full_name: fullName, 
            email: email,
            updated_at: new Date()
        }])
        .select();

    if (profileError) {
        console.error('Profile Upsert Error:', profileError);
        throw profileError;
    }

    // success
    delete otpStore[email];
    res.status(200).json({
      success: true,
      message: "Registration successful and account confirmed!",
      user: profileData ? profileData[0] : { id: userId, full_name: fullName }
    });

    } catch (error) {
    console.error('Detailed Error:', error);
    res.status(500).json({
      success: false,
      message: "Registration failed: " + (error.message || "Internal Server Error"),
    });
  }
});

// ======================================
// LOGIN API
// ======================================
app.post("/login", async (req, res) => {
    const { email, password } = req.body;

    if (!email || !password) {
        return res.status(400).json({ success: false, message: 'Email and password are required' });
    }

    try {
        const { data, error } = await supabase
            .from('profiles')
            .select('*')
            .eq('email', email)
            .eq('password', password)
            .single();

        if (error || !data) {
            return res.status(401).json({ success: false, message: 'Invalid email or password' });
        }

        res.status(200).json({ success: true, message: 'Login successful', user: data });

    } catch (error) {
        console.error('Detailed Error:', error);
        res.status(500).json({ success: false, message: 'Login failed' });
    }
});

// ======================================
// START SERVER
// ======================================
// ======================================
// SUPABASE WEBHOOK - NOTIFICATIONS
// ======================================
app.post("/message-webhook", async (req, res) => {
    try {
        console.log("\n--- Webhook Triggered ---");
        
        // Supabase webhooks send data in 'record'. Handle both INSERT and UPDATE just in case.
        const record = req.body.record || req.body; 
        
        if (!record || (!record.sender_id && !record.receiver_id)) {
            console.log("⚠️ No valid record found in payload:", JSON.stringify(req.body));
            return res.status(400).send("No record found");
        }

        const { sender_id, receiver_id, content, attachment_type } = record;
        console.log(`📩 New message: [From: ${sender_id}] -> [To: ${receiver_id}] ${attachment_type ? `(Attachment: ${attachment_type})` : ""}`);

        // 1. Get Sender's Name
        const { data: sender, error: senderError } = await supabase
            .from('profiles')
            .select('full_name')
            .eq('id', sender_id)
            .single();
        
        if (senderError) console.error("❌ Error fetching sender:", senderError.message);

        // 2. Get Receiver's FCM Token
        const { data: receiver, error: receiverError } = await supabase
            .from('profiles')
            .select('fcm_token, is_online, full_name')
            .eq('id', receiver_id)
            .single();

        if (receiverError) {
            console.error("❌ Error fetching receiver:", receiverError.message);
        }

        if (receiver && receiver.fcm_token) {
            console.log(`🚀 Sending Push Notification to: ${receiver.full_name || receiver_id}`);
            console.log(`📱 Online Status: ${receiver.is_online ? "Online" : "Offline"}`);

            try {
                let notificationBody = content || "You received a new message";
                if (attachment_type) {
                    notificationBody = `📁 Sent ${attachment_type === 'image' ? 'an image' : attachment_type === 'video' ? 'a video' : attachment_type === 'contact' ? 'a contact' : 'a file'}`;
                }

                await sendPushNotification(
                    receiver.fcm_token,
                    sender ? sender.full_name : "New Message",
                    notificationBody,
                    { 
                        type: "chat_message",
                        sender_id: sender_id,
                        receiver_id: receiver_id
                    }
                );
                console.log(`✅ Success: Notification sent to ${receiver_id}`);
            } catch (sendError) {
                console.error("❌ Firebase Send Error:", sendError.message);
                // If token is invalid, clear it
                if (sendError.message.includes("not-found") || sendError.message.includes("not-registered")) {
                    console.log(`🧹 Cleaning up invalid token for ${receiver_id}`);
                    await supabase.from('profiles').update({ fcm_token: null }).eq('id', receiver_id);
                }
            }
        } else {
            console.log(`⚠️ Skip: Receiver ${receiver_id} has no FCM token in DB.`);
        }

        res.status(200).send("Notification processed");
    } catch (error) {
        console.error("💥 Critical Webhook Error:", error);
        res.status(500).send("Internal Server Error");
    }
});

// ======================================
// DIRECT CHAT - SEND NOTIFICATION
// ======================================
app.post("/api/send-chat-notification", async (req, res) => {
    try {
        const { sender_id, receiver_id, content, attachment_type } = req.body;

        if (!sender_id || !receiver_id) {
            return res.status(400).json({ success: false, message: "sender_id and receiver_id are required" });
        }

        console.log(`\n📩 Direct message notification request: [From: ${sender_id}] -> [To: ${receiver_id}]`);

        // 1. Get Sender's Name
        const { data: sender, error: senderError } = await supabase
            .from('profiles')
            .select('full_name')
            .eq('id', sender_id)
            .single();
        
        if (senderError) console.error("❌ Error fetching sender:", senderError.message);

        // 2. Get Receiver's FCM Token and Profile
        const { data: receiver, error: receiverError } = await supabase
            .from('profiles')
            .select('fcm_token, is_online, full_name')
            .eq('id', receiver_id)
            .single();

        if (receiverError) {
            console.error("❌ Error fetching receiver:", receiverError.message);
        }

        if (receiver && receiver.fcm_token) {
            console.log(`🚀 Sending Push Notification to: ${receiver.full_name || receiver_id}`);
            console.log(`📱 Online Status: ${receiver.is_online ? "Online" : "Offline"}`);

            let notificationBody = content || "You received a new message";
            if (attachment_type) {
                notificationBody = `📁 Sent ${attachment_type === 'image' ? 'an image' : attachment_type === 'video' ? 'a video' : attachment_type === 'contact' ? 'a contact' : 'a file'}`;
            }

            try {
                await sendPushNotification(
                    receiver.fcm_token,
                    sender ? sender.full_name : "New Message",
                    notificationBody,
                    { 
                        type: "chat_message",
                        sender_id: sender_id,
                        receiver_id: receiver_id
                    }
                );
                console.log(`✅ Success: Notification sent to ${receiver_id}`);
            } catch (sendError) {
                console.error("❌ Firebase Send Error:", sendError.message);
                if (sendError.message.includes("not-found") || sendError.message.includes("not-registered")) {
                    console.log(`🧹 Cleaning up invalid token for ${receiver_id}`);
                    await supabase.from('profiles').update({ fcm_token: null }).eq('id', receiver_id);
                }
            }
        } else {
            console.log(`⚠️ Skip: Receiver ${receiver_id} has no FCM token in DB.`);
        }

        res.status(200).json({ success: true, message: "Notification process complete" });
    } catch (error) {
        console.error("💥 Critical Direct Chat Notification Error:", error);
        res.status(500).json({ success: false, message: "Internal Server Error" });
    }
});

// ======================================
// TEST UTILITIES (LOGS DASHBOARD ACTIONS)
// ======================================

// 1. Send Test Notification to All
app.post("/api/test/notify-all", async (req, res) => {
    console.log("🚀 Starting Global Test Notification from Web Panel...");
    try {
        const { data: profiles, error } = await supabase
            .from('profiles')
            .select('id, full_name, fcm_token')
            .not('fcm_token', 'is', null);

        if (error) {
            console.error("❌ Error fetching profiles:", error.message);
            return res.status(500).json({ success: false, message: error.message });
        }

        if (!profiles || profiles.length === 0) {
            console.log("⚠️ No users found with FCM tokens in the database.");
            return res.status(200).json({ success: true, message: "No users found with FCM tokens." });
        }

        console.log(`Found ${profiles.length} users with FCM tokens.`);

        // Process sending asynchronously
        (async () => {
            for (const profile of profiles) {
                try {
                    console.log(`Sending test notification to: ${profile.full_name}`);
                    await sendPushNotification(
                        profile.fcm_token,
                        "Global Test Notification",
                        `Hi ${profile.full_name}, this is a test from the web log console!`,
                        { type: "test_all", sent_at: new Date().toISOString() }
                    );
                    console.log(`✅ Success: Sent to ${profile.full_name}`);
                } catch (err) {
                    console.error(`❌ Failed: Could not send to ${profile.full_name}:`, err.message);
                    if (err.message.includes("not-found") || err.message.includes("not-registered")) {
                        console.log(`🧹 Cleaning up invalid token for ${profile.full_name}`);
                        await supabase.from('profiles').update({ fcm_token: null }).eq('id', profile.id);
                    }
                }
            }
            console.log("🏁 Global notification process finished.");
        })();

        res.status(200).json({ success: true, message: `Notification broadcast started for ${profiles.length} users.` });
    } catch (err) {
        console.error("💥 Critical test-notify-all error:", err);
        res.status(500).json({ success: false, message: err.message });
    }
});

// 2. Delete All Chats
app.post("/api/test/delete-chats", async (req, res) => {
    console.log("🧹 Starting to clear all chat and task messages from Web Panel...");
    try {
        // Delete standard messages
        const { error: msgError } = await supabase
            .from('messages')
            .delete()
            .gt('id', 0);

        if (msgError) {
            console.error("❌ Error deleting direct messages:", msgError.message);
            return res.status(500).json({ success: false, message: msgError.message });
        }

        // Delete group task messages
        const { error: groupMsgError } = await supabase
            .from('task_group_messages')
            .delete()
            .gt('id', 0);

        if (groupMsgError) {
            console.error("❌ Error deleting task group messages:", groupMsgError.message);
            return res.status(500).json({ success: false, message: groupMsgError.message });
        }

        console.log("✅ All chat and group messages deleted successfully.");
        res.status(200).json({ success: true, message: "All chat and group messages deleted successfully." });
    } catch (err) {
        console.error("💥 Critical delete-chats error:", err);
        res.status(500).json({ success: false, message: err.message });
    }
});

// 3. Create Demo Task Workflow
app.post("/api/test/create-demo-task", async (req, res) => {
    console.log("🚀 Starting Demo Task Creation from Web Panel...");
    try {
        const { data: profiles, error: pError } = await supabase
            .from('profiles')
            .select('id, full_name, email');

        if (pError || !profiles || profiles.length === 0) {
            console.error("❌ Error fetching profiles:", pError ? pError.message : "No profiles found");
            return res.status(500).json({ success: false, message: pError ? pError.message : "No profiles found in database." });
        }

        const creator = profiles[0];
        const leader = profiles[1] ? profiles[1] : creator;

        const demoSteps = [
            { title: "UI/UX Design Phase", description: "Design the high-fidelity mockups for the app." },
            { title: "Frontend Development", description: "Build the Flutter screens and navigation." },
            { title: "Backend Integration", description: "Connect APIs and setup database sync." },
            { title: "QA & Bug Fixing", description: "Test all features and fix reported issues." },
            { title: "App Store Deployment", description: "Submit the app to Play Store and App Store." }
        ];

        const stepsWithUsers = demoSteps.map((step, index) => {
            const assignedUser = profiles[index % profiles.length];
            return {
                title: step.title,
                description: step.description,
                assigned_users: [assignedUser.id]
            };
        });

        const payload = {
            title: "Project: Global App Launch 2026",
            description: "This is a full-cycle development task with 5 dependent stages. Completing one stage will automatically notify the next person in line.",
            priority: "urgent",
            deadline: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString(),
            created_by: creator.id,
            leader_id: leader.id,
            members: profiles.map(u => u.id),
            steps: stepsWithUsers
        };

        // Call the internal `/tasks` endpoint by making a local fetch call
        const localPort = process.env.PORT || 5000;
        const tasksUrl = `http://localhost:${localPort}/tasks`;

        console.log(`Sending demo task payload internally to ${tasksUrl}...`);
        
        const response = await fetch(tasksUrl, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });

        const result = await response.json();

        if (result.success) {
            console.log("✨ SUCCESS! Demo Task Created via Web Panel.");
            res.status(200).json({ 
                success: true, 
                message: `Demo Task Created! ID: ${result.task.id}, Active Step: ${result.task.steps[0].step_title}` 
            });
        } else {
            console.error("❌ Failed to create task:", result.message);
            res.status(500).json({ success: false, message: result.message });
        }
    } catch (err) {
        console.error("💥 Critical create-demo-task error:", err);
        res.status(500).json({ success: false, message: err.message });
    }
});

// ======================================
// TASK WORKFLOW SYSTEM
// ======================================

// --- Helper: Send task notification (FCM + DB) ---
async function sendTaskNotification(userId, taskId, type, title, body) {
    try {
        // Store in DB
        await supabase.from('notifications').insert({
            user_id: userId,
            task_id: taskId,
            type: type,
            title: title,
            body: body,
        });

        // Send FCM push
        const { data: user } = await supabase
            .from('profiles')
            .select('fcm_token, full_name')
            .eq('id', userId)
            .single();

        if (user && user.fcm_token) {
            await sendPushNotification(
                user.fcm_token,
                title,
                body,
                { type: type, task_id: taskId }
            );
            console.log(`✅ Task notification sent to ${user.full_name || userId}`);
        }
    } catch (err) {
        console.error(`❌ Error sending task notification:`, err.message);
        // If token is invalid, clear it
        if (err.message.includes("not-found") || err.message.includes("not-registered")) {
            console.log(`🧹 Cleaning up invalid token for user ${userId}`);
            await supabase.from('profiles').update({ fcm_token: null }).eq('id', userId);
        }
    }
}

// --- Helper: Get assigned users for a step ---
async function getStepAssignedUsers(stepId) {
    const { data } = await supabase
        .from('task_step_members')
        .select('user_id')
        .eq('step_id', stepId);
    return data ? data.map(d => d.user_id) : [];
}

// ======================================
// CREATE TASK
// ======================================
app.post("/tasks", async (req, res) => {
    try {
        const { title, description, priority, deadline, created_by, steps, members, leader_id } = req.body;

        if (!title || !created_by || !steps || steps.length === 0) {
            return res.status(400).json({ success: false, message: "Title, creator, and at least one step are required" });
        }

        // 1. Create task
        const { data: task, error: taskError } = await supabase
            .from('tasks')
            .insert({
                title,
                description: description || null,
                priority: priority || 'medium',
                deadline: deadline || null,
                created_by,
                status: 'active',
            })
            .select()
            .single();

        if (taskError) throw taskError;

        // 2. Add creator as admin member
        const memberInserts = [{ task_id: task.id, user_id: created_by, role: 'admin' }];

        // 3. Add leader if specified
        if (leader_id && leader_id !== created_by) {
            memberInserts.push({ task_id: task.id, user_id: leader_id, role: 'leader' });
        }

        // 4. Add other members
        if (members && members.length > 0) {
            for (const memberId of members) {
                if (!memberInserts.find(m => m.user_id === memberId)) {
                    memberInserts.push({ task_id: task.id, user_id: memberId, role: 'member' });
                }
            }
        }

        // Also add users assigned to steps as members
        for (const step of steps) {
            if (step.assigned_users) {
                for (const uid of step.assigned_users) {
                    if (!memberInserts.find(m => m.user_id === uid)) {
                        memberInserts.push({ task_id: task.id, user_id: uid, role: 'member' });
                    }
                }
            }
        }

        const { error: memberError } = await supabase
            .from('task_members')
            .insert(memberInserts);
        if (memberError) throw memberError;

        // 5. Create steps (first step is ready, rest are pending. Calculate deadlines sequentially)
        let currentDeadline = new Date();
        const stepInserts = steps.map((step, index) => {
            const duration = parseInt(step.duration_days) || 2;
            currentDeadline = new Date(currentDeadline.getTime() + duration * 24 * 60 * 60 * 1000);
            return {
                task_id: task.id,
                step_number: index + 1,
                step_title: step.title,
                description: step.description || null,
                status: index === 0 ? 'ready' : 'pending',
                duration_days: duration,
                deadline: currentDeadline.toISOString(),
            };
        });

        const { data: createdSteps, error: stepError } = await supabase
            .from('task_steps')
            .insert(stepInserts)
            .select()
            .order('step_number', { ascending: true });
        if (stepError) throw stepError;

        // If the task didn't specify a deadline, or the steps' combined duration is later, update the task deadline
        const finalDeadlineStr = currentDeadline.toISOString();
        if (!deadline) {
            await supabase.from('tasks').update({ deadline: finalDeadlineStr }).eq('id', task.id);
            task.deadline = finalDeadlineStr;
        }

        // 6. Assign users to steps
        const stepMemberInserts = [];
        for (let i = 0; i < steps.length; i++) {
            if (steps[i].assigned_users) {
                for (const uid of steps[i].assigned_users) {
                    stepMemberInserts.push({
                        step_id: createdSteps[i].id,
                        user_id: uid,
                    });
                }
            }
        }

        if (stepMemberInserts.length > 0) {
            const { error: smError } = await supabase
                .from('task_step_members')
                .insert(stepMemberInserts);
            if (smError) throw smError;
        }

        // 7. Notify all members: "You have been added to a new task"
        for (const member of memberInserts) {
            if (member.user_id !== created_by) {
                await sendTaskNotification(
                    member.user_id,
                    task.id,
                    'task_created',
                    'New Task Assigned',
                    `You have been added to: ${title}`
                );
            }
        }

        // 8. Notify first step assigned users: "It's your turn"
        if (createdSteps.length > 0) {
            const firstStepUsers = await getStepAssignedUsers(createdSteps[0].id);
            for (const uid of firstStepUsers) {
                await sendTaskNotification(
                    uid,
                    task.id,
                    'step_activated',
                    "It's Your Turn!",
                    `Start working on: ${createdSteps[0].step_title} in ${title}`
                );
            }

            // Notify second step assigned users to prepare!
            if (createdSteps.length > 1) {
                const secondStepUsers = await getStepAssignedUsers(createdSteps[1].id);
                for (const uid of secondStepUsers) {
                    await sendTaskNotification(
                        uid,
                        task.id,
                        'step_upcoming',
                        "Upcoming Task",
                        `Your turn is next. You can start preparing for: ${createdSteps[1].step_title}`
                    );
                }
            }
        }

        // 9. Create welcome message in task group chat
        await supabase.from('task_group_messages').insert({
            task_id: task.id,
            sender_id: created_by,
            content: `📋 Task "${title}" has been created. Let's get started!`,
        });

        console.log(`✅ Task created: ${title} (${createdSteps.length} steps, ${memberInserts.length} members)`);

        res.status(201).json({
            success: true,
            message: "Task created successfully",
            task: { ...task, steps: createdSteps },
        });

    } catch (error) {
        console.error("❌ Create task error:", error);
        res.status(500).json({ success: false, message: error.message || "Failed to create task" });
    }
});

// ======================================
// GET TASKS FOR USER
// ======================================
app.get("/tasks/:userId", async (req, res) => {
    try {
        const { userId } = req.params;

        // Get all task IDs where user is a member
        const { data: memberData, error: memberError } = await supabase
            .from('task_members')
            .select('task_id, role')
            .eq('user_id', userId);

        if (memberError) throw memberError;
        if (!memberData || memberData.length === 0) {
            return res.json({ success: true, tasks: [] });
        }

        const taskIds = memberData.map(m => m.task_id);
        const roleMap = {};
        memberData.forEach(m => { roleMap[m.task_id] = m.role; });

        // Get tasks with steps
        const { data: tasks, error: taskError } = await supabase
            .from('tasks')
            .select(`
                *,
                task_steps (id, step_number, step_title, status, completed_at, deadline, duration_days, extension_days, started_at, started_by, blocked_reason),
                task_members (user_id, role)
            `)
            .in('id', taskIds)
            .order('created_at', { ascending: false });

        if (taskError) throw taskError;

        // Add user's role to each task
        const tasksWithRole = tasks.map(t => ({
            ...t,
            my_role: roleMap[t.id] || 'member',
        }));

        res.json({ success: true, tasks: tasksWithRole });

    } catch (error) {
        console.error("❌ Get tasks error:", error);
        res.status(500).json({ success: false, message: error.message });
    }
});

// ======================================
// GET TASK DETAIL
// ======================================
app.get("/tasks/detail/:taskId", async (req, res) => {
    try {
        const { taskId } = req.params;

        const { data: task, error: taskError } = await supabase
            .from('tasks')
            .select(`
                *,
                task_steps (
                    id, step_number, step_title, description, status, completed_at, completed_by,
                    deadline, duration_days, extension_days, started_at, started_by, blocked_reason
                ),
                task_members (
                    user_id, role,
                    profiles:user_id (id, full_name, email)
                )
            `)
            .eq('id', taskId)
            .single();

        if (taskError) throw taskError;

        // Get step assignments
        if (task.task_steps) {
            // Sort steps by step_number
            task.task_steps.sort((a, b) => a.step_number - b.step_number);

            for (const step of task.task_steps) {
                const { data: stepMembers } = await supabase
                    .from('task_step_members')
                    .select(`
                        user_id,
                        profiles:user_id (id, full_name, email)
                    `)
                    .eq('step_id', step.id);

                step.assigned_users = stepMembers || [];
            }
        }

        // Get creator profile
        const { data: creator } = await supabase
            .from('profiles')
            .select('id, full_name, email')
            .eq('id', task.created_by)
            .single();

        task.creator = creator;

        res.json({ success: true, task });

    } catch (error) {
        console.error("❌ Get task detail error:", error);
        res.status(500).json({ success: false, message: error.message });
    }
});

// ======================================
// ======================================
// COMPLETE STEP — DEPENDENCY ENGINE 🔥
// ======================================
app.post("/tasks/:taskId/complete-step", async (req, res) => {
    try {
        const { taskId } = req.params;
        const { user_id, step_id } = req.body;

        if (!user_id || !step_id) {
            return res.status(400).json({ success: false, message: "user_id and step_id are required" });
        }

        // 1. Verify the step exists and is active/started
        const { data: step, error: stepError } = await supabase
            .from('task_steps')
            .select('*')
            .eq('id', step_id)
            .eq('task_id', taskId)
            .single();

        if (stepError || !step) {
            return res.status(404).json({ success: false, message: "Step not found" });
        }

        const activeStatuses = ['active', 'in_progress', 'extended'];
        if (!activeStatuses.includes(step.status)) {
            return res.status(400).json({ success: false, message: "This step is not currently active/in progress" });
        }

        // 2. Verify user is assigned to this step or is privileged
        const assignedUsers = await getStepAssignedUsers(step_id);
        const { data: memberRole } = await supabase
            .from('task_members')
            .select('role')
            .eq('task_id', taskId)
            .eq('user_id', user_id)
            .single();

        const isAssigned = assignedUsers.includes(user_id);
        const isPrivileged = memberRole && (memberRole.role === 'admin' || memberRole.role === 'leader');

        if (!isAssigned && !isPrivileged) {
            return res.status(403).json({ success: false, message: "You are not assigned to this step" });
        }

        // Check if there is a leader or admin for the task
        const { data: taskMembers } = await supabase
            .from('task_members')
            .select('user_id, role')
            .eq('task_id', taskId);

        const hasLeaderOrAdmin = taskMembers && taskMembers.some(m => m.role === 'admin' || m.role === 'leader');

        const { data: completedByUser } = await supabase
            .from('profiles')
            .select('full_name')
            .eq('id', user_id)
            .single();
        const completerName = completedByUser?.full_name || 'Someone';

        // 3. Flow control: if member and there is a leader, send to waiting_approval
        if (!isPrivileged && hasLeaderOrAdmin) {
            await supabase
                .from('task_steps')
                .update({ status: 'waiting_approval' })
                .eq('id', step_id);

            // Group message
            await supabase.from('task_group_messages').insert({
                task_id: taskId,
                sender_id: user_id,
                content: `📋 ${completerName} completed "${step.step_title}" and is waiting for leader approval.`,
            });

            // Notify leaders and admins
            const leadersAndAdmins = taskMembers.filter(m => m.role === 'admin' || m.role === 'leader');
            for (const la of leadersAndAdmins) {
                await sendTaskNotification(
                    la.user_id,
                    taskId,
                    'step_waiting_approval',
                    "Approval Required",
                    `${completerName} submitted step "${step.step_title}" for approval.`
                );
            }

            return res.json({
                success: true,
                message: "Step submitted for approval",
                status: "waiting_approval",
                task_completed: false
            });
        }

        // 4. Otherwise, mark step completed directly
        const { error: updateError } = await supabase
            .from('task_steps')
            .update({
                status: 'completed',
                completed_at: new Date().toISOString(),
                completed_by: user_id,
            })
            .eq('id', step_id);

        if (updateError) throw updateError;

        // 5. Handle activating the next step
        const result = await activateNextStep(taskId, step.step_number, user_id, step.step_title);
        res.json(result);

    } catch (error) {
        console.error("❌ Complete step error:", error);
        res.status(500).json({ success: false, message: error.message });
    }
});

// Helper: Activate Next Step in Workflow
async function activateNextStep(taskId, currentStepNumber, completedByUserId, completedStepTitle) {
    // Check for next step
    const { data: nextStep } = await supabase
        .from('task_steps')
        .select('*')
        .eq('task_id', taskId)
        .eq('step_number', currentStepNumber + 1)
        .single();

    // Get task title for notifications
    const { data: task } = await supabase
        .from('tasks')
        .select('title')
        .eq('id', taskId)
        .single();
    const taskTitle = task ? task.title : 'Task';

    const { data: completedByUser } = await supabase
        .from('profiles')
        .select('full_name')
        .eq('id', completedByUserId)
        .single();
    const completerName = completedByUser?.full_name || 'Someone';

    if (nextStep) {
        // Activate next step
        await supabase
            .from('task_steps')
            .update({ status: 'ready' })
            .eq('id', nextStep.id);

        // Notify next step's assigned users
        const nextStepUsers = await getStepAssignedUsers(nextStep.id);
        for (const uid of nextStepUsers) {
            await sendTaskNotification(
                uid,
                taskId,
                'step_activated',
                "It's Your Turn!",
                `Step "${nextStep.step_title}" is ready in ${taskTitle}. Please start working.`
            );
        }

        // Notify step after next (if any) to prepare!
        const { data: upcomingStep } = await supabase
            .from('task_steps')
            .select('id, step_title')
            .eq('task_id', taskId)
            .eq('step_number', currentStepNumber + 2)
            .single();

        if (upcomingStep) {
            const upcomingUsers = await getStepAssignedUsers(upcomingStep.id);
            for (const uid of upcomingUsers) {
                await sendTaskNotification(
                    uid,
                    taskId,
                    'step_upcoming',
                    "Upcoming Task",
                    `Your turn is next. You can start preparing for: ${upcomingStep.step_title}`
                );
            }
        }

        // Notify in group chat
        await supabase.from('task_group_messages').insert({
            task_id: taskId,
            sender_id: completedByUserId,
            content: `✅ ${completerName} completed "${completedStepTitle}". Next up: "${nextStep.step_title}"`,
        });

        console.log(`🔄 Step ${currentStepNumber} completed → Step ${currentStepNumber + 1} activated (READY)`);

        return {
            success: true,
            message: "Step completed, next step is ready",
            completed_step: currentStepNumber,
            next_step: currentStepNumber + 1,
            task_completed: false,
            status: "completed"
        };
    } else {
        // No more steps — Task is complete!
        await supabase
            .from('tasks')
            .update({ status: 'completed', updated_at: new Date().toISOString() })
            .eq('id', taskId);

        // Notify ALL task members
        const { data: allMembers } = await supabase
            .from('task_members')
            .select('user_id')
            .eq('task_id', taskId);

        if (allMembers) {
            for (const member of allMembers) {
                await sendTaskNotification(
                    member.user_id,
                    taskId,
                    'task_completed',
                    "🎉 Task Completed!",
                    `"${taskTitle}" has been completed!`
                );
            }
        }

        // Group chat message
        await supabase.from('task_group_messages').insert({
            task_id: taskId,
            sender_id: completedByUserId,
            content: `🎉 All steps completed! Task "${taskTitle}" is now finished!`,
        });

        console.log(`🏁 Task "${taskTitle}" COMPLETED!`);

        return {
            success: true,
            message: "Task completed!",
            completed_step: currentStepNumber,
            task_completed: true,
            status: "completed"
        };
    }
}

// ======================================
// START TASK STEP
// ======================================
app.post("/tasks/:taskId/steps/:stepId/start", async (req, res) => {
    try {
        const { taskId, stepId } = req.params;
        const { user_id } = req.body;

        if (!user_id) {
            return res.status(400).json({ success: false, message: "user_id is required" });
        }

        // 1. Verify step exists and is ready
        const { data: step, error: stepError } = await supabase
            .from('task_steps')
            .select('*')
            .eq('id', stepId)
            .eq('task_id', taskId)
            .single();

        if (stepError || !step) {
            return res.status(404).json({ success: false, message: "Step not found" });
        }

        if (step.status !== 'ready') {
            return res.status(400).json({ success: false, message: "Step must be in 'ready' status to start" });
        }

        // 2. Verify role / assignment
        const assignedUsers = await getStepAssignedUsers(stepId);
        const { data: memberRole } = await supabase
            .from('task_members')
            .select('role')
            .eq('task_id', taskId)
            .eq('user_id', user_id)
            .single();

        const isAssigned = assignedUsers.includes(user_id);
        const isPrivileged = memberRole && (memberRole.role === 'admin' || memberRole.role === 'leader');

        if (!isAssigned && !isPrivileged) {
            return res.status(403).json({ success: false, message: "You are not assigned to this step" });
        }

        // 3. Start step
        const now = new Date().toISOString();
        await supabase
            .from('task_steps')
            .update({
                status: 'in_progress',
                started_at: now,
                started_by: user_id
            })
            .eq('id', stepId);

        // Get user name
        const { data: userProfile } = await supabase
            .from('profiles')
            .select('full_name')
            .eq('id', user_id)
            .single();

        const userName = userProfile?.full_name || 'Someone';

        // Group chat system message
        await supabase.from('task_group_messages').insert({
            task_id: taskId,
            sender_id: user_id,
            content: `🟢 Step "${step.step_title}" started by ${userName}.`,
        });

        res.json({ success: true, message: "Step started successfully", started_at: now });

    } catch (error) {
        console.error("❌ Start step error:", error);
        res.status(500).json({ success: false, message: error.message });
    }
});

// ======================================
// BLOCK / UNBLOCK STEP
// ======================================
app.post("/tasks/:taskId/steps/:stepId/block", async (req, res) => {
    try {
        const { taskId, stepId } = req.params;
        const { user_id, reason } = req.body;

        if (!user_id || !reason) {
            return res.status(400).json({ success: false, message: "user_id and reason are required" });
        }

        const { data: step } = await supabase.from('task_steps').select('*').eq('id', stepId).single();
        if (!step) return res.status(404).json({ success: false, message: "Step not found" });

        // Update status
        await supabase
            .from('task_steps')
            .update({ status: 'blocked', blocked_reason: reason })
            .eq('id', stepId);

        const { data: userProfile } = await supabase.from('profiles').select('full_name').eq('id', user_id).single();
        const userName = userProfile?.full_name || 'Someone';

        // Group message
        await supabase.from('task_group_messages').insert({
            task_id: taskId,
            sender_id: user_id,
            content: `⚠️ "${step.step_title}" has been marked BLOCKED by ${userName}. Reason: "${reason}"`,
        });

        res.json({ success: true, message: "Step marked blocked" });

    } catch (error) {
        console.error("❌ Block step error:", error);
        res.status(500).json({ success: false, message: error.message });
    }
});

app.post("/tasks/:taskId/steps/:stepId/unblock", async (req, res) => {
    try {
        const { taskId, stepId } = req.params;
        const { user_id } = req.body;

        if (!user_id) {
            return res.status(400).json({ success: false, message: "user_id is required" });
        }

        const { data: step } = await supabase.from('task_steps').select('*').eq('id', stepId).single();
        if (!step) return res.status(404).json({ success: false, message: "Step not found" });

        // Restore status to either in_progress or ready depending on if it has been started
        const targetStatus = step.started_at ? 'in_progress' : 'ready';

        await supabase
            .from('task_steps')
            .update({ status: targetStatus, blocked_reason: null })
            .eq('id', stepId);

        const { data: userProfile } = await supabase.from('profiles').select('full_name').eq('id', user_id).single();
        const userName = userProfile?.full_name || 'Someone';

        // Group message
        await supabase.from('task_group_messages').insert({
            task_id: taskId,
            sender_id: user_id,
            content: `🟢 "${step.step_title}" is now UNBLOCKED by ${userName}.`,
        });

        res.json({ success: true, message: "Step unblocked", status: targetStatus });

    } catch (error) {
        console.error("❌ Unblock step error:", error);
        res.status(500).json({ success: false, message: error.message });
    }
});

// ======================================
// APPROVE / REJECT STEP COMPLETION
// ======================================
app.post("/tasks/:taskId/steps/:stepId/approve-completion", async (req, res) => {
    try {
        const { taskId, stepId } = req.params;
        const { user_id } = req.body;

        if (!user_id) {
            return res.status(400).json({ success: false, message: "user_id is required" });
        }

        // Verify resolver role
        const { data: member } = await supabase
            .from('task_members')
            .select('role')
            .eq('task_id', taskId)
            .eq('user_id', user_id)
            .single();

        if (!member || (member.role !== 'admin' && member.role !== 'leader')) {
            return res.status(403).json({ success: false, message: "Only admin or leader can approve step completion" });
        }

        // Get step
        const { data: step } = await supabase.from('task_steps').select('*').eq('id', stepId).single();
        if (!step) return res.status(404).json({ success: false, message: "Step not found" });

        // Update step status
        await supabase
            .from('task_steps')
            .update({
                status: 'completed',
                completed_at: new Date().toISOString(),
                completed_by: step.completed_by || user_id
            })
            .eq('id', stepId);

        const { data: userProfile } = await supabase.from('profiles').select('full_name').eq('id', user_id).single();
        const leaderName = userProfile?.full_name || 'Leader';

        // Activate next step
        const result = await activateNextStep(taskId, step.step_number, user_id, step.step_title);

        // Notify group chat of leader approval
        await supabase.from('task_group_messages').insert({
            task_id: taskId,
            sender_id: user_id,
            content: `✅ ${leaderName} approved completion of "${step.step_title}".`,
        });

        res.json({ success: true, message: "Step completion approved", ...result });

    } catch (error) {
        console.error("❌ Approve completion error:", error);
        res.status(500).json({ success: false, message: error.message });
    }
});

app.post("/tasks/:taskId/steps/:stepId/reject-completion", async (req, res) => {
    try {
        const { taskId, stepId } = req.params;
        const { user_id } = req.body;

        if (!user_id) {
            return res.status(400).json({ success: false, message: "user_id is required" });
        }

        // Verify resolver role
        const { data: member } = await supabase
            .from('task_members')
            .select('role')
            .eq('task_id', taskId)
            .eq('user_id', user_id)
            .single();

        if (!member || (member.role !== 'admin' && member.role !== 'leader')) {
            return res.status(403).json({ success: false, message: "Only admin or leader can reject step completion" });
        }

        // Get step
        const { data: step } = await supabase.from('task_steps').select('*').eq('id', stepId).single();
        if (!step) return res.status(404).json({ success: false, message: "Step not found" });

        // Update step status back to in_progress (or extended if it has extension days)
        const targetStatus = step.extension_days > 0 ? 'extended' : 'in_progress';
        await supabase
            .from('task_steps')
            .update({ status: targetStatus })
            .eq('id', stepId);

        const { data: userProfile } = await supabase.from('profiles').select('full_name').eq('id', user_id).single();
        const leaderName = userProfile?.full_name || 'Leader';

        // Group message
        await supabase.from('task_group_messages').insert({
            task_id: taskId,
            sender_id: user_id,
            content: `❌ ${leaderName} rejected completion of "${step.step_title}". Step is sent back to ${targetStatus.toUpperCase()}.`,
        });

        // Notify assigned users
        const assignedUsers = await getStepAssignedUsers(stepId);
        for (const uid of assignedUsers) {
            await sendTaskNotification(
                uid,
                taskId,
                'step_rejected',
                "Step Rejected",
                `Completion for "${step.step_title}" was rejected by ${leaderName}. Please review and update.`
            );
        }

        res.json({ success: true, message: "Step completion rejected, status set to " + targetStatus });

    } catch (error) {
        console.error("❌ Reject completion error:", error);
        res.status(500).json({ success: false, message: error.message });
    }
});

// ======================================
// DEADLINE EXTENSION REQUESTS
// ======================================
app.post("/tasks/:taskId/steps/:stepId/request-extension", async (req, res) => {
    try {
        const { taskId, stepId } = req.params;
        const { user_id, days_requested, reason } = req.body;

        if (!user_id || !days_requested) {
            return res.status(400).json({ success: false, message: "user_id and days_requested are required" });
        }

        const { data: step } = await supabase.from('task_steps').select('*').eq('id', stepId).single();
        if (!step) return res.status(404).json({ success: false, message: "Step not found" });

        // 1. Create extension request
        const { data: request, error: reqError } = await supabase
            .from('deadline_extensions')
            .insert({
                task_id: taskId,
                step_id: stepId,
                requested_by: user_id,
                days_requested: parseInt(days_requested),
                reason: reason || null,
                status: 'pending'
            })
            .select()
            .single();

        if (reqError) throw reqError;

        // Get profiles
        const { data: requester } = await supabase.from('profiles').select('full_name').eq('id', user_id).single();
        const requesterName = requester?.full_name || 'Someone';

        // 2. Group chat system message
        await supabase.from('task_group_messages').insert({
            task_id: taskId,
            sender_id: user_id,
            content: `📋 ${requesterName} requested a ${days_requested}-day extension for "${step.step_title}". Reason: "${reason || 'No reason provided'}"`,
        });

        // 3. Notify leaders/admins
        const { data: taskMembers } = await supabase.from('task_members').select('user_id, role').eq('task_id', taskId);
        const leadersAndAdmins = taskMembers ? taskMembers.filter(m => m.role === 'admin' || m.role === 'leader') : [];

        for (const la of leadersAndAdmins) {
            await sendTaskNotification(
                la.user_id,
                taskId,
                'extension_requested',
                "Extension Requested",
                `${requesterName} requested ${days_requested} extra days for "${step.step_title}".`
            );
        }

        res.json({ success: true, message: "Extension request submitted successfully", request });

    } catch (error) {
        console.error("❌ Request extension error:", error);
        res.status(500).json({ success: false, message: error.message });
    }
});

app.get("/tasks/:taskId/extension-requests", async (req, res) => {
    try {
        const { taskId } = req.params;

        const { data: requests, error } = await supabase
            .from('deadline_extensions')
            .select(`
                *,
                requester:requested_by (id, full_name, email),
                step:step_id (id, step_title, step_number)
            `)
            .eq('task_id', taskId)
            .order('created_at', { ascending: false });

        if (error) throw error;

        res.json({ success: true, requests: requests || [] });

    } catch (error) {
        console.error("❌ Get extension requests error:", error);
        res.status(500).json({ success: false, message: error.message });
    }
});

app.post("/tasks/:taskId/extensions/:extensionId/resolve", async (req, res) => {
    try {
        const { taskId, extensionId } = req.params;
        const { user_id, status } = req.body; // 'approved' or 'rejected'

        if (!user_id || !status || !['approved', 'rejected'].includes(status)) {
            return res.status(400).json({ success: false, message: "user_id and status ('approved'/'rejected') are required" });
        }

        // Verify resolver role
        const { data: member } = await supabase
            .from('task_members')
            .select('role')
            .eq('task_id', taskId)
            .eq('user_id', user_id)
            .single();

        if (!member || (member.role !== 'admin' && member.role !== 'leader')) {
            return res.status(403).json({ success: false, message: "Only admin or leader can resolve extensions" });
        }

        // 1. Get extension request details
        const { data: extReq } = await supabase
            .from('deadline_extensions')
            .select('*')
            .eq('id', extensionId)
            .single();

        if (!extReq) return res.status(404).json({ success: false, message: "Extension request not found" });
        if (extReq.status !== 'pending') return res.status(400).json({ success: false, message: "Request already resolved" });

        const resolverProfile = await supabase.from('profiles').select('full_name').eq('id', user_id).single();
        const resolverName = resolverProfile.data?.full_name || 'Leader';

        const step = await supabase.from('task_steps').select('*').eq('id', extReq.step_id).single();
        const stepTitle = step.data ? step.data.step_title : 'Step';

        if (status === 'approved') {
            const days = extReq.days_requested;

            // Update extension record
            await supabase
                .from('deadline_extensions')
                .update({ status: 'approved', resolved_at: new Date().toISOString(), resolved_by: user_id })
                .eq('id', extensionId);

            // Fetch current step deadline to increment it
            let currentDl = step.data.deadline ? new Date(step.data.deadline) : new Date();
            const newStepDl = new Date(currentDl.getTime() + days * 24 * 60 * 60 * 1000);

            // Update current step
            await supabase
                .from('task_steps')
                .update({
                    deadline: newStepDl.toISOString(),
                    extension_days: (step.data.extension_days || 0) + days,
                    status: 'extended'
                })
                .eq('id', extReq.step_id);

            // Cascade shift: Shift subsequent steps
            const { data: subsequentSteps } = await supabase
                .from('task_steps')
                .select('id, deadline, step_title')
                .eq('task_id', taskId)
                .gt('step_number', step.data.step_number);

            if (subsequentSteps) {
                for (const sub of subsequentSteps) {
                    if (sub.deadline) {
                        const subDl = new Date(sub.deadline);
                        const newSubDl = new Date(subDl.getTime() + days * 24 * 60 * 60 * 1000);
                        await supabase
                            .from('task_steps')
                            .update({ deadline: newSubDl.toISOString() })
                            .eq('id', sub.id);

                        // Notify subsequent step assigned users that their deadlines shifted
                        const subUsers = await getStepAssignedUsers(sub.id);
                        for (const uid of subUsers) {
                            await sendTaskNotification(
                                uid,
                                taskId,
                                'step_deadline_shifted',
                                "Deadline Shifted",
                                `The upcoming step "${sub.step_title}" deadline shifted by +${days} days.`
                            );
                        }
                    }
                }
            }

            // Shift overall task deadline too
            const { data: taskData } = await supabase.from('tasks').select('deadline, title').eq('id', taskId).single();
            if (taskData && taskData.deadline) {
                const taskDl = new Date(taskData.deadline);
                const newTaskDl = new Date(taskDl.getTime() + days * 24 * 60 * 60 * 1000);
                await supabase.from('tasks').update({ deadline: newTaskDl.toISOString() }).eq('id', taskId);
            }

            // Post group chat update
            await supabase.from('task_group_messages').insert({
                task_id: taskId,
                sender_id: user_id,
                content: `✅ Extension request of +${days} days for "${stepTitle}" APPROVED by ${resolverName}. New Deadline: ${newStepDl.toLocaleDateString()}`,
            });

            // Notify requester
            await sendTaskNotification(
                extReq.requested_by,
                taskId,
                'extension_approved',
                "Extension Approved",
                `Your extension of +${days} days for "${stepTitle}" was approved by ${resolverName}.`
            );

        } else {
            // Rejected
            await supabase
                .from('deadline_extensions')
                .update({ status: 'rejected', resolved_at: new Date().toISOString(), resolved_by: user_id })
                .eq('id', extensionId);

            // Post group chat update
            await supabase.from('task_group_messages').insert({
                task_id: taskId,
                sender_id: user_id,
                content: `❌ Extension request of +${extReq.days_requested} days for "${stepTitle}" REJECTED by ${resolverName}.`,
            });

            // Notify requester
            await sendTaskNotification(
                extReq.requested_by,
                taskId,
                'extension_rejected',
                "Extension Rejected",
                `Your extension request for "${stepTitle}" was rejected by ${resolverName}.`
            );
        }

        res.json({ success: true, message: "Request resolved successfully" });

    } catch (error) {
        console.error("❌ Resolve extension error:", error);
        res.status(500).json({ success: false, message: error.message });
    }
});

// ======================================
// MEMBER MANAGEMENT
// ======================================
app.post("/tasks/:taskId/members", async (req, res) => {
    try {
        const { taskId } = req.params;
        const { user_id, target_user_id, role } = req.body;

        if (!user_id || !target_user_id || !role) {
            return res.status(400).json({ success: false, message: "user_id, target_user_id and role are required" });
        }

        // Verify requester role
        const { data: member } = await supabase
            .from('task_members')
            .select('role')
            .eq('task_id', taskId)
            .eq('user_id', user_id)
            .single();

        if (!member || (member.role !== 'admin' && member.role !== 'leader')) {
            return res.status(403).json({ success: false, message: "Only admin or leader can manage members" });
        }

        // Leader cannot add admin role
        if (member.role === 'leader' && role === 'admin') {
            return res.status(403).json({ success: false, message: "Leaders cannot assign 'admin' role" });
        }

        // Check if member already exists
        const { data: existing } = await supabase
            .from('task_members')
            .select('*')
            .eq('task_id', taskId)
            .eq('user_id', target_user_id)
            .single();

        if (existing) {
            // Update
            await supabase
                .from('task_members')
                .update({ role })
                .eq('task_id', taskId)
                .eq('user_id', target_user_id);
        } else {
            // Insert
            await supabase
                .from('task_members')
                .insert({ task_id: taskId, user_id: target_user_id, role });
        }

        // Notify member
        const { data: task } = await supabase.from('tasks').select('title').eq('id', taskId).single();
        await sendTaskNotification(
            target_user_id,
            taskId,
            'member_added',
            "Added to Task Group",
            `You have been added to "${task?.title || 'Task'}" as ${role.toUpperCase()}.`
        );

        res.json({ success: true, message: "Member added/updated successfully" });

    } catch (error) {
        console.error("❌ Add member error:", error);
        res.status(500).json({ success: false, message: error.message });
    }
});

app.delete("/tasks/:taskId/members", async (req, res) => {
    try {
        const { taskId } = req.params;
        const { user_id, target_user_id } = req.body;

        if (!user_id || !target_user_id) {
            return res.status(400).json({ success: false, message: "user_id and target_user_id are required" });
        }

        // Verify requester role
        const { data: member } = await supabase
            .from('task_members')
            .select('role')
            .eq('task_id', taskId)
            .eq('user_id', user_id)
            .single();

        if (!member || (member.role !== 'admin' && member.role !== 'leader')) {
            return res.status(403).json({ success: false, message: "Only admin or leader can remove members" });
        }

        // Check target role
        const { data: targetMember } = await supabase
            .from('task_members')
            .select('role')
            .eq('task_id', taskId)
            .eq('user_id', target_user_id)
            .single();

        if (!targetMember) return res.status(404).json({ success: false, message: "Member not found" });

        // Leader cannot remove admin or delete admin
        if (member.role === 'leader' && targetMember.role === 'admin') {
            return res.status(403).json({ success: false, message: "Leaders cannot remove Admin members" });
        }

        // Delete member
        await supabase
            .from('task_members')
            .delete()
            .eq('task_id', taskId)
            .eq('user_id', target_user_id);

        // Delete from task_step_members for steps under this task
        const { data: steps } = await supabase.from('task_steps').select('id').eq('task_id', taskId);
        if (steps && steps.length > 0) {
            const stepIds = steps.map(s => s.id);
            await supabase
                .from('task_step_members')
                .delete()
                .in('step_id', stepIds)
                .eq('user_id', target_user_id);
        }

        // Notify member
        const { data: task } = await supabase.from('tasks').select('title').eq('id', taskId).single();
        await sendTaskNotification(
            target_user_id,
            taskId,
            'member_removed',
            "Removed from Task Group",
            `You have been removed from "${task?.title || 'Task'}".`
        );

        res.json({ success: true, message: "Member removed successfully" });

    } catch (error) {
        console.error("❌ Remove member error:", error);
        res.status(500).json({ success: false, message: error.message });
    }
});

// ======================================
// EDIT / REORDER WORKFLOW STEPS
// ======================================
app.put("/tasks/:taskId/steps", async (req, res) => {
    try {
        const { taskId } = req.params;
        const { user_id, steps } = req.body; // steps array with title, description, assigned_users, step_number, duration_days

        if (!user_id || !steps || !Array.isArray(steps)) {
            return res.status(400).json({ success: false, message: "user_id and steps array are required" });
        }

        // Verify role
        const { data: member } = await supabase
            .from('task_members')
            .select('role')
            .eq('task_id', taskId)
            .eq('user_id', user_id)
            .single();

        if (!member || (member.role !== 'admin' && member.role !== 'leader')) {
            return res.status(403).json({ success: false, message: "Only admin or leader can edit workflow steps" });
        }

        // 1. Get existing steps to preserve statuses if applicable, or do full recreation.
        // For simplicity and safety, let's delete assignments for task, then delete steps, and re-create them.
        // Wait, deleting steps might delete cascade, but what if some steps are already completed?
        // Let's perform inline updates for existing step IDs, delete omitted ones, and insert new ones!
        
        const { data: existingSteps } = await supabase
            .from('task_steps')
            .select('id')
            .eq('task_id', taskId);
        const existingIds = existingSteps ? existingSteps.map(s => s.id) : [];
        const incomingIds = steps.filter(s => s.id).map(s => s.id);

        // Delete steps that are omitted
        const omittedIds = existingIds.filter(id => !incomingIds.includes(id));
        if (omittedIds.length > 0) {
            await supabase.from('task_steps').delete().in('id', omittedIds);
        }

        // Re-calculate sequential deadlines based on duration
        let currentDeadline = new Date();
        const updatedSteps = [];

        for (let i = 0; i < steps.length; i++) {
            const step = steps[i];
            const duration = parseInt(step.duration_days) || 2;
            currentDeadline = new Date(currentDeadline.getTime() + duration * 24 * 60 * 60 * 1000);

            const stepPayload = {
                task_id: taskId,
                step_number: i + 1,
                step_title: step.title,
                description: step.description || null,
                duration_days: duration,
                deadline: currentDeadline.toISOString(),
            };

            // If it is step 1 and was not started, set ready.
            if (i === 0 && !step.status) {
                stepPayload.status = 'ready';
            } else if (step.status) {
                stepPayload.status = step.status;
            } else {
                stepPayload.status = 'pending';
            }

            let savedStepId;
            if (step.id) {
                // Update
                const { data: updatedStep, error: uErr } = await supabase
                    .from('task_steps')
                    .update(stepPayload)
                    .eq('id', step.id)
                    .select()
                    .single();
                if (uErr) throw uErr;
                savedStepId = updatedStep.id;
                updatedSteps.push(updatedStep);
            } else {
                // Insert
                const { data: insertedStep, error: iErr } = await supabase
                    .from('task_steps')
                    .insert(stepPayload)
                    .select()
                    .single();
                if (iErr) throw iErr;
                savedStepId = insertedStep.id;
                updatedSteps.push(insertedStep);
            }

            // Update assigned users for this step
            // First delete existing assignments
            await supabase.from('task_step_members').delete().eq('step_id', savedStepId);

            // Insert new assignments
            if (step.assigned_users && step.assigned_users.length > 0) {
                const stepMemberInserts = step.assigned_users.map(uid => ({
                    step_id: savedStepId,
                    user_id: uid
                }));
                await supabase.from('task_step_members').insert(stepMemberInserts);
            }
        }

        // Update overall task deadline to the final step's deadline
        const finalDeadlineStr = currentDeadline.toISOString();
        await supabase.from('tasks').update({ deadline: finalDeadlineStr }).eq('id', taskId);

        // Group message
        const { data: userProfile } = await supabase.from('profiles').select('full_name').eq('id', user_id).single();
        await supabase.from('task_group_messages').insert({
            task_id: taskId,
            sender_id: user_id,
            content: `📋 Workflow steps updated by ${userProfile?.full_name || 'Leader'}.`,
        });

        res.json({ success: true, message: "Workflow steps updated successfully", steps: updatedSteps });

    } catch (error) {
        console.error("❌ Edit steps error:", error);
        res.status(500).json({ success: false, message: error.message });
    }
});

// ======================================
// UPDATE TASK (admin/leader)
// ======================================
app.put("/tasks/:taskId", async (req, res) => {
    try {
        const { taskId } = req.params;
        const { user_id, title, description, priority, deadline, status } = req.body;

        // Verify role
        const { data: member } = await supabase
            .from('task_members')
            .select('role')
            .eq('task_id', taskId)
            .eq('user_id', user_id)
            .single();

        if (!member || (member.role !== 'admin' && member.role !== 'leader')) {
            return res.status(403).json({ success: false, message: "Only admin or leader can update tasks" });
        }

        const updates = {};
        if (title !== undefined) updates.title = title;
        if (description !== undefined) updates.description = description;
        if (priority !== undefined) updates.priority = priority;
        if (deadline !== undefined) updates.deadline = deadline;
        if (status !== undefined) updates.status = status;

        const { data: task, error } = await supabase
            .from('tasks')
            .update(updates)
            .eq('id', taskId)
            .select()
            .single();

        if (error) throw error;

        res.json({ success: true, message: "Task updated", task });

    } catch (error) {
        console.error("❌ Update task error:", error);
        res.status(500).json({ success: false, message: error.message });
    }
});

// ======================================
// DELETE TASK (admin only)
// ======================================
app.delete("/tasks/:taskId", async (req, res) => {
    try {
        const { taskId } = req.params;
        const { user_id } = req.body;

        // Verify admin role
        const { data: member } = await supabase
            .from('task_members')
            .select('role')
            .eq('task_id', taskId)
            .eq('user_id', user_id)
            .single();

        if (!member || member.role !== 'admin') {
            return res.status(403).json({ success: false, message: "Only admin can delete tasks" });
        }

        const { error } = await supabase
            .from('tasks')
            .delete()
            .eq('id', taskId);

        if (error) throw error;

        console.log(`🗑️ Task ${taskId} deleted by ${user_id}`);
        res.json({ success: true, message: "Task deleted" });

    } catch (error) {
        console.error("❌ Delete task error:", error);
        res.status(500).json({ success: false, message: error.message });
    }
});

// ======================================
// TASK GROUP CHAT - SEND MESSAGE
// ======================================
app.post("/tasks/:taskId/messages", async (req, res) => {
    try {
        const { taskId } = req.params;
        const { sender_id, content, attachment_url, attachment_type } = req.body;

        // Verify user is a task member
        const { data: member } = await supabase
            .from('task_members')
            .select('role')
            .eq('task_id', taskId)
            .eq('user_id', sender_id)
            .single();

        if (!member) {
            return res.status(403).json({ success: false, message: "You are not a member of this task" });
        }

        const { data: message, error } = await supabase
            .from('task_group_messages')
            .insert({
                task_id: taskId,
                sender_id,
                content: content || null,
                attachment_url: attachment_url || null,
                attachment_type: attachment_type || null,
            })
            .select()
            .single();

        if (error) throw error;

        // Trigger push notifications to other task members asynchronously
        (async () => {
            try {
                // 1. Get task title
                const { data: task } = await supabase
                    .from('tasks')
                    .select('title')
                    .eq('id', taskId)
                    .single();
                
                const taskTitle = task ? task.title : 'Task Group';

                // 2. Get sender name
                const { data: sender } = await supabase
                    .from('profiles')
                    .select('full_name')
                    .eq('id', sender_id)
                    .single();

                const senderName = sender ? sender.full_name : 'Someone';

                // 3. Get all task members except sender
                const { data: members, error: mError } = await supabase
                    .from('task_members')
                    .select('user_id')
                    .eq('task_id', taskId)
                    .neq('user_id', sender_id);

                if (mError) {
                    console.error("❌ Error fetching task members for notification:", mError.message);
                    return;
                }

                if (!members || members.length === 0) return;

                const memberIds = members.map(m => m.user_id);

                // 4. Fetch FCM tokens for those members
                const { data: profiles, error: pError } = await supabase
                    .from('profiles')
                    .select('id, fcm_token, full_name')
                    .in('id', memberIds)
                    .not('fcm_token', 'is', null);

                if (pError) {
                    console.error("❌ Error fetching member profiles for notification:", pError.message);
                    return;
                }

                if (!profiles || profiles.length === 0) return;

                console.log(`🚀 Sending task group message notifications to ${profiles.length} users...`);

                let notificationBody = content || "Sent a new message";
                if (attachment_type) {
                    notificationBody = `📁 Sent ${attachment_type === 'image' ? 'an image' : attachment_type === 'video' ? 'a video' : attachment_type === 'contact' ? 'a contact' : 'a file'}`;
                }

                // 5. Send FCM notifications
                for (const profile of profiles) {
                    try {
                        await sendPushNotification(
                            profile.fcm_token,
                            `Group: ${taskTitle}`,
                            `${senderName}: ${notificationBody}`,
                            {
                                type: "task_group_message",
                                task_id: taskId,
                                sender_id: sender_id
                            }
                        );
                        console.log(`✅ Success: Group chat notification sent to ${profile.full_name}`);
                    } catch (err) {
                        console.error(`❌ Failed: Group notification to ${profile.full_name}:`, err.message);
                        if (err.message.includes("not-found") || err.message.includes("not-registered")) {
                            console.log(`🧹 Cleaning up invalid token for ${profile.full_name}`);
                            await supabase.from('profiles').update({ fcm_token: null }).eq('id', profile.id);
                        }
                    }
                }
            } catch (notifyErr) {
                console.error("❌ Error running group message notifications background job:", notifyErr);
            }
        })();

        res.status(201).json({ success: true, message: message });

    } catch (error) {
        console.error("❌ Send task message error:", error);
        res.status(500).json({ success: false, message: error.message });
    }
});

// ======================================
// TASK GROUP CHAT - GET MESSAGES
// ======================================
app.get("/tasks/:taskId/messages", async (req, res) => {
    try {
        const { taskId } = req.params;

        const { data: messages, error } = await supabase
            .from('task_group_messages')
            .select(`
                *,
                profiles:sender_id (id, full_name, email)
            `)
            .eq('task_id', taskId)
            .order('created_at', { ascending: true });

        if (error) throw error;

        res.json({ success: true, messages: messages || [] });

    } catch (error) {
        console.error("❌ Get task messages error:", error);
        res.status(500).json({ success: false, message: error.message });
    }
});

// ======================================
// GET NOTIFICATIONS FOR USER
// ======================================
app.get("/notifications/:userId", async (req, res) => {
    try {
        const { userId } = req.params;

        const { data: notifications, error } = await supabase
            .from('notifications')
            .select('*')
            .eq('user_id', userId)
            .order('created_at', { ascending: false })
            .limit(50);

        if (error) throw error;

        res.json({ success: true, notifications: notifications || [] });

    } catch (error) {
        console.error("❌ Get notifications error:", error);
        res.status(500).json({ success: false, message: error.message });
    }
});

// ======================================
// MARK NOTIFICATION AS READ
// ======================================
app.put("/notifications/:notificationId/read", async (req, res) => {
    try {
        const { notificationId } = req.params;

        const { error } = await supabase
            .from('notifications')
            .update({ is_read: true })
            .eq('id', notificationId);

        if (error) throw error;

        res.json({ success: true, message: "Notification marked as read" });

    } catch (error) {
        console.error("❌ Mark notification read error:", error);
        res.status(500).json({ success: false, message: error.message });
    }
});

// ======================================
// START SERVER
// ======================================
const PORT = process.env.PORT || 5000;
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on port ${PORT}`);
  if (process.env.RENDER_EXTERNAL_URL) {
    console.log(`Live URL: ${process.env.RENDER_EXTERNAL_URL}`);
  } else {
    console.log(`Local Access: http://localhost:${PORT}`);
  }
});

// ======================================
// WEB LOGS DASHBOARD HTML PAGE
// ======================================
const HTML_LOGS_PAGE = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Backend Live Web Console</title>
  <link rel="icon" type="image/svg+xml" href="data:image/svg+xml,<svg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 100 100%22><text y=%22.9em%22 font-size=%2290%22>📟</text></svg>">
  <style>
    @import url('https://fonts.googleapis.com/css2?family=Fira+Code:wght@400;500;600&family=Outfit:wght@300;400;500;600;700&display=swap');

    :root {
      --bg-color: #06070a;
      --card-bg: rgba(17, 20, 28, 0.7);
      --terminal-bg: #030406;
      --border-color: rgba(255, 255, 255, 0.08);
      --text-main: #f1f5f9;
      --text-muted: #94a3b8;
      
      --color-info: #38bdf8;
      --color-info-bg: rgba(56, 189, 248, 0.1);
      --color-warn: #fbbf24;
      --color-warn-bg: rgba(251, 191, 36, 0.1);
      --color-error: #f87171;
      --color-error-bg: rgba(248, 113, 113, 0.1);
      --color-purple: #8b5cf6;
      
      --shadow-glow: 0 0 20px rgba(139, 92, 246, 0.15);
    }

    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
      scrollbar-width: thin;
      scrollbar-color: rgba(255,255,255,0.15) transparent;
    }

    /* Custom Scrollbars */
    ::-webkit-scrollbar {
      width: 8px;
      height: 8px;
    }
    ::-webkit-scrollbar-track {
      background: transparent;
    }
    ::-webkit-scrollbar-thumb {
      background: rgba(255, 255, 255, 0.1);
      border-radius: 4px;
    }
    ::-webkit-scrollbar-thumb:hover {
      background: rgba(255, 255, 255, 0.2);
    }

    body {
      background-color: var(--bg-color);
      color: var(--text-main);
      font-family: 'Outfit', sans-serif;
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      padding: 24px;
      overflow: hidden;
    }

    .background-glow {
      position: absolute;
      top: -10%;
      left: 50%;
      transform: translateX(-50%);
      width: 600px;
      height: 300px;
      background: radial-gradient(circle, rgba(139, 92, 246, 0.08) 0%, rgba(0,0,0,0) 70%);
      pointer-events: none;
      z-index: -1;
    }

    .container {
      max-width: 1300px;
      width: 100%;
      margin: 0 auto;
      display: flex;
      flex-direction: column;
      flex: 1;
      height: calc(100vh - 48px);
    }

    /* HEADER */
    .header {
      background: var(--card-bg);
      backdrop-filter: blur(16px);
      -webkit-backdrop-filter: blur(16px);
      border: 1px solid var(--border-color);
      border-radius: 20px;
      padding: 20px 28px;
      margin-bottom: 20px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      box-shadow: var(--shadow-glow), 0 10px 40px -10px rgba(0, 0, 0, 0.5);
    }

    .header-logo {
      display: flex;
      align-items: center;
      gap: 12px;
    }

    .header-logo .icon {
      font-size: 24px;
      background: linear-gradient(135deg, #a78bfa, #8b5cf6);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
      filter: drop-shadow(0 2px 8px rgba(139, 92, 246, 0.4));
    }

    .header-logo h1 {
      font-size: 20px;
      font-weight: 600;
      letter-spacing: -0.5px;
      background: linear-gradient(135deg, #f1f5f9, #cbd5e1);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
    }

    .status-dashboard {
      display: flex;
      align-items: center;
      gap: 24px;
    }

    .status-badge {
      display: flex;
      align-items: center;
      gap: 8px;
      background: rgba(16, 185, 129, 0.08);
      border: 1px solid rgba(16, 185, 129, 0.2);
      border-radius: 30px;
      padding: 6px 14px;
      font-size: 13px;
      font-weight: 500;
      color: #34d399;
    }

    .status-badge.offline {
      background: rgba(239, 68, 68, 0.08);
      border: 1px solid rgba(239, 68, 68, 0.2);
      color: #f87171;
    }

    .status-badge .dot {
      width: 8px;
      height: 8px;
      background-color: currentColor;
      border-radius: 50%;
      box-shadow: 0 0 8px currentColor;
    }

    .status-badge.online .dot {
      animation: pulse 1.8s infinite;
    }

    @keyframes pulse {
      0% { transform: scale(0.9); opacity: 0.6; }
      50% { transform: scale(1.15); opacity: 1; box-shadow: 0 0 12px currentColor; }
      100% { transform: scale(0.9); opacity: 0.6; }
    }

    .stat-box {
      font-size: 13px;
      color: var(--text-muted);
    }
    .stat-box span {
      color: var(--text-main);
      font-weight: 600;
      font-family: 'Fira Code', monospace;
    }

    /* TOOLBAR & CONTROLS */
    .controls {
      background: var(--card-bg);
      backdrop-filter: blur(16px);
      -webkit-backdrop-filter: blur(16px);
      border: 1px solid var(--border-color);
      border-radius: 16px;
      padding: 14px 20px;
      margin-bottom: 20px;
      display: flex;
      flex-wrap: wrap;
      justify-content: space-between;
      align-items: center;
      gap: 16px;
      box-shadow: 0 4px 20px rgba(0, 0, 0, 0.2);
    }

    .filter-buttons {
      display: flex;
      gap: 8px;
    }

    .btn-filter {
      background: rgba(255, 255, 255, 0.03);
      border: 1px solid rgba(255, 255, 255, 0.06);
      border-radius: 8px;
      padding: 8px 14px;
      font-family: 'Outfit', sans-serif;
      font-size: 13px;
      font-weight: 500;
      color: var(--text-muted);
      cursor: pointer;
      transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
    }

    .btn-filter:hover {
      background: rgba(255, 255, 255, 0.07);
      color: var(--text-main);
      border-color: rgba(255, 255, 255, 0.12);
    }

    .btn-filter.active {
      color: #ffffff;
      box-shadow: 0 2px 10px rgba(139, 92, 246, 0.2);
    }

    .btn-filter.active[data-level="all"] { background: var(--color-purple); border-color: var(--color-purple); }
    .btn-filter.active[data-level="info"] { background: var(--color-info); border-color: var(--color-info); color: #000; font-weight: 600; }
    .btn-filter.active[data-level="warn"] { background: var(--color-warn); border-color: var(--color-warn); color: #000; font-weight: 600; }
    .btn-filter.active[data-level="error"] { background: var(--color-error); border-color: var(--color-error); color: #fff; }

    .search-container {
      position: relative;
      flex: 1;
      max-width: 350px;
      min-width: 200px;
    }

    .search-input {
      width: 100%;
      background: rgba(0, 0, 0, 0.3);
      border: 1px solid var(--border-color);
      border-radius: 8px;
      padding: 8px 14px 8px 36px;
      color: var(--text-main);
      font-family: 'Outfit', sans-serif;
      font-size: 13.5px;
      transition: all 0.2s;
    }

    .search-input:focus {
      outline: none;
      border-color: var(--color-purple);
      box-shadow: 0 0 8px rgba(139, 92, 246, 0.25);
    }

    .search-icon {
      position: absolute;
      left: 12px;
      top: 50%;
      transform: translateY(-50%);
      color: var(--text-muted);
      pointer-events: none;
      font-size: 14px;
    }

    .action-buttons {
      display: flex;
      align-items: center;
      gap: 12px;
    }

    .toggle-container {
      display: flex;
      align-items: center;
      gap: 8px;
      font-size: 13px;
      color: var(--text-muted);
      cursor: pointer;
      user-select: none;
    }

    .switch {
      position: relative;
      display: inline-block;
      width: 36px;
      height: 20px;
    }

    .switch input {
      opacity: 0;
      width: 0;
      height: 0;
    }

    .slider {
      position: absolute;
      cursor: pointer;
      top: 0;
      left: 0;
      right: 0;
      bottom: 0;
      background-color: rgba(255,255,255,0.1);
      transition: .3s;
      border-radius: 34px;
      border: 1px solid var(--border-color);
    }

    .slider:before {
      position: absolute;
      content: "";
      height: 12px;
      width: 12px;
      left: 3px;
      bottom: 3px;
      background-color: var(--text-muted);
      transition: .3s;
      border-radius: 50%;
    }

    input:checked + .slider {
      background-color: var(--color-purple);
      border-color: var(--color-purple);
    }

    input:checked + .slider:before {
      transform: translateX(16px);
      background-color: white;
    }

    .btn-action {
      background: rgba(255, 255, 255, 0.05);
      border: 1px solid var(--border-color);
      border-radius: 8px;
      padding: 8px 14px;
      font-family: 'Outfit', sans-serif;
      font-size: 13px;
      font-weight: 500;
      color: var(--text-main);
      cursor: pointer;
      display: flex;
      align-items: center;
      gap: 6px;
      transition: all 0.2s;
    }

    .btn-action:hover {
      background: rgba(255, 255, 255, 0.1);
      border-color: rgba(255, 255, 255, 0.2);
    }

    .btn-action.clear:hover {
      background: rgba(239, 68, 68, 0.1);
      border-color: rgba(239, 68, 68, 0.3);
      color: #f87171;
    }

    .btn-action:disabled {
      opacity: 0.5;
      cursor: not-allowed;
      pointer-events: none;
    }

    .admin-controls {
      background: rgba(17, 20, 28, 0.85);
      border-color: rgba(139, 92, 246, 0.15);
      margin-top: -10px;
      box-shadow: 0 4px 20px rgba(139, 92, 246, 0.05);
    }
    
    .admin-title {
      display: flex;
      align-items: center;
      gap: 8px;
      font-size: 13.5px;
      font-weight: 600;
      color: var(--color-purple);
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    
    .admin-title .icon {
      font-size: 16px;
      animation: flash 2s infinite;
    }
    
    @keyframes flash {
      0%, 100% { opacity: 0.6; }
      50% { opacity: 1; }
    }

    .admin-buttons {
      display: flex;
      gap: 12px;
      flex-wrap: wrap;
    }

    .admin-btn {
      position: relative;
      overflow: hidden;
    }

    .admin-btn:active {
      transform: scale(0.97);
    }

    .spinner {
      display: inline-block;
      width: 12px;
      height: 12px;
      border: 2px solid rgba(255,255,255,0.3);
      border-radius: 50%;
      border-top-color: #fff;
      animation: spin 0.8s linear infinite;
    }

    @keyframes spin {
      to { transform: rotate(360deg); }
    }

    /* CONSOLE TERMINAL */
    .terminal-container {
      background: var(--terminal-bg);
      border: 1px solid var(--border-color);
      border-radius: 16px;
      flex: 1;
      display: flex;
      flex-direction: column;
      overflow: hidden;
      box-shadow: inset 0 4px 30px rgba(0, 0, 0, 0.8), 0 10px 30px rgba(0,0,0,0.5);
    }

    .terminal-header {
      background: rgba(255, 255, 255, 0.02);
      border-bottom: 1px solid var(--border-color);
      padding: 10px 16px;
      display: flex;
      align-items: center;
      gap: 6px;
    }

    .terminal-dot {
      width: 10px;
      height: 10px;
      border-radius: 50%;
    }
    .terminal-dot.red { background-color: #ef4444; }
    .terminal-dot.yellow { background-color: #eab308; }
    .terminal-dot.green { background-color: #22c55e; }

    .terminal-title {
      font-family: 'Fira Code', monospace;
      font-size: 11px;
      color: var(--text-muted);
      margin-left: 10px;
    }

    .terminal-body {
      flex: 1;
      padding: 18px;
      overflow-y: auto;
      font-family: 'Fira Code', monospace;
      font-size: 13px;
      line-height: 1.6;
      color: #cbd5e1;
    }

    .log-row {
      display: flex;
      align-items: flex-start;
      margin-bottom: 8px;
      animation: fadeIn 0.15s ease-out forwards;
      word-break: break-all;
    }

    @keyframes fadeIn {
      from { opacity: 0; transform: translateY(4px); }
      to { opacity: 1; transform: translateY(0); }
    }

    .log-index {
      color: rgba(255, 255, 255, 0.18);
      min-width: 32px;
      user-select: none;
      text-align: right;
      padding-right: 12px;
    }

    .log-time {
      color: #64748b;
      margin-right: 12px;
      user-select: none;
    }

    .log-badge {
      display: inline-block;
      font-size: 10px;
      font-weight: 600;
      padding: 1px 6px;
      border-radius: 4px;
      text-transform: uppercase;
      margin-right: 12px;
      min-width: 54px;
      text-align: center;
      user-select: none;
    }

    .log-badge.info { background: var(--color-info-bg); color: var(--color-info); border: 1px solid rgba(56, 189, 248, 0.2); }
    .log-badge.warn { background: var(--color-warn-bg); color: var(--color-warn); border: 1px solid rgba(251, 191, 36, 0.2); }
    .log-badge.error { background: var(--color-error-bg); color: var(--color-error); border: 1px solid rgba(248, 113, 113, 0.2); }

    .log-message {
      white-space: pre-wrap;
      flex: 1;
      color: #e2e8f0;
    }

    .log-message.error-text {
      color: #fca5a5;
    }
    .log-message.warn-text {
      color: #fde047;
    }

    .no-logs {
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      height: 100%;
      color: var(--text-muted);
      gap: 12px;
      user-select: none;
    }

    .no-logs-icon {
      font-size: 32px;
      opacity: 0.5;
    }

    /* Pulse active log badge */
    .log-badge.pulse {
      box-shadow: 0 0 8px currentColor;
    }
  </style>
</head>
<body>
  <div class="background-glow"></div>
  <div class="container">
    <!-- HEADER -->
    <div class="header">
      <div class="header-logo">
        <span class="icon">📟</span>
        <h1>AnandSwami App Live Terminal</h1>
      </div>
      <div class="status-dashboard">
        <div class="stat-box">Uptime: <span id="uptime">0s</span></div>
        <div class="stat-box">Buffer: <span id="total-count">0</span> / 1000 logs</div>
        <div id="status-badge" class="status-badge online">
          <div id="status-indicator" class="dot"></div>
          <span id="status-text">Connecting...</span>
        </div>
      </div>
    </div>

    <!-- CONTROLS -->
    <div class="controls">
      <div class="filter-buttons">
        <button class="btn-filter active" data-level="all">All Logs</button>
        <button class="btn-filter" data-level="info">Info</button>
        <button class="btn-filter" data-level="warn">Warning</button>
        <button class="btn-filter" data-level="error">Error</button>
      </div>

      <div class="search-container">
        <span class="search-icon">🔍</span>
        <input type="text" id="search-input" class="search-input" placeholder="Filter logs by keyword...">
      </div>

      <div class="action-buttons">
        <label class="toggle-container">
          <div class="switch">
            <input type="checkbox" id="autoscroll-toggle" checked>
            <span class="slider"></span>
          </div>
          Auto-scroll
        </label>
        
        <button id="btn-copy" class="btn-action">
          <span>📋</span> Copy
        </button>
        
        <button id="btn-clear" class="btn-action clear">
          <span>🗑️</span> Clear Buffer
        </button>
      </div>
    </div>

    <!-- ADMIN ACTIONS -->
    <div class="controls admin-controls">
      <div class="admin-title">
        <span class="icon">⚡</span>
        <span>Admin Controls</span>
      </div>
      <div class="admin-buttons">
        <button id="btn-notify-all" class="btn-action admin-btn">
          <span>🔔</span> Notify All Users
        </button>
        <button id="btn-create-task" class="btn-action admin-btn">
          <span>📋</span> Create Demo Task
        </button>
        <button id="btn-delete-chats" class="btn-action admin-btn clear">
          <span>🧹</span> Delete All Chats
        </button>
      </div>
    </div>

    <!-- TERMINAL -->
    <div class="terminal-container">
      <div class="terminal-header">
        <div class="terminal-dot red"></div>
        <div class="terminal-dot yellow"></div>
        <div class="terminal-dot green"></div>
        <span class="terminal-title">server.log — tail -n 1000 -f</span>
      </div>
      <div id="terminal-body" class="terminal-body">
        <div class="no-logs">
          <div class="no-logs-icon">💾</div>
          <div>No logs captured yet. Trigger backend operations to see logs.</div>
        </div>
      </div>
    </div>
  </div>

  <script>
    let lastLogCount = -1;
    let allLogs = [];
    let activeFilter = 'all';
    let searchQuery = '';
    let isFetching = false;

    // Elements
    const terminalBody = document.getElementById('terminal-body');
    const uptimeEl = document.getElementById('uptime');
    const totalCountEl = document.getElementById('total-count');
    const statusBadge = document.getElementById('status-badge');
    const statusIndicator = document.getElementById('status-indicator');
    const statusText = document.getElementById('status-text');
    const searchInput = document.getElementById('search-input');
    const autoscrollToggle = document.getElementById('autoscroll-toggle');
    const btnCopy = document.getElementById('btn-copy');
    const btnClear = document.getElementById('btn-clear');
    const filterButtons = document.querySelectorAll('.btn-filter');

    // Format Uptime Helper
    function formatUptime(seconds) {
      if (seconds < 60) return seconds + 's';
      const m = Math.floor(seconds / 60);
      const s = seconds % 60;
      if (m < 60) return m + 'm ' + s + 's';
      const h = Math.floor(m / 60);
      const min = m % 60;
      return h + 'h ' + min + 'm ' + s + 's';
    }

    // Format ISO timestamp to local hh:mm:ss.ms
    function formatTimestamp(isoStr) {
      try {
        const date = new Date(isoStr);
        const hh = String(date.getHours()).padStart(2, '0');
        const mm = String(date.getMinutes()).padStart(2, '0');
        const ss = String(date.getSeconds()).padStart(2, '0');
        const ms = String(date.getMilliseconds()).padStart(3, '0');
        return hh + ':' + mm + ':' + ss + '.' + ms;
      } catch (e) {
        return isoStr;
      }
    }

    // Escape HTML to prevent XSS in log view
    function escapeHtml(text) {
      const map = {
        '&': '&amp;',
        '<': '&lt;',
        '>': '&gt;',
        '"': '&quot;',
        "'": '&#039;'
      };
      return text.replace(/[&<>"']/g, function(m) { return map[m]; });
    }

    // Render Logs
    function renderLogs() {
      // Filter logs
      let filtered = allLogs;
      
      // 1. Level Filter
      if (activeFilter !== 'all') {
        filtered = filtered.filter(log => log.type === activeFilter);
      }
      
      // 2. Search Query Filter
      if (searchQuery.trim() !== '') {
        const query = searchQuery.toLowerCase();
        filtered = filtered.filter(log => log.message.toLowerCase().includes(query));
      }

      // Check if empty
      if (filtered.length === 0) {
        terminalBody.innerHTML = \`
          <div class="no-logs">
            <div class="no-logs-icon">🔍</div>
            <div>No matching logs found.</div>
          </div>
        \`;
        return;
      }

      // Build rows
      let html = '';
      filtered.forEach((log, index) => {
        const levelClass = log.type === 'error' ? 'error' : log.type === 'warn' ? 'warn' : 'info';
        const textClass = log.type === 'error' ? 'error-text' : log.type === 'warn' ? 'warn-text' : '';
        html += \`
          <div class="log-row">
            <span class="log-index">\${index + 1}</span>
            <span class="log-time">\${formatTimestamp(log.timestamp)}</span>
            <span class="log-badge \${levelClass}">\${log.type}</span>
            <pre class="log-message \${textClass}">\${escapeHtml(log.message)}</pre>
          </div>
        \`;
      });

      const wasAtBottom = terminalBody.scrollHeight - terminalBody.clientHeight <= terminalBody.scrollTop + 50;

      terminalBody.innerHTML = html;

      // Auto scroll logic
      if (autoscrollToggle.checked && (wasAtBottom || lastLogCount === -1)) {
        terminalBody.scrollTop = terminalBody.scrollHeight;
      }
    }

    // Fetch Logs from Backend
    async function fetchLogs() {
      if (isFetching) return;
      isFetching = true;
      try {
        const res = await fetch('/api/logs');
        if (!res.ok) throw new Error('API response not ok');
        const data = await res.json();
        
        uptimeEl.textContent = formatUptime(data.uptime);
        totalCountEl.textContent = data.count;

        const lastFetched = data.logs.length > 0 ? data.logs[data.logs.length - 1].timestamp : '';
        const lastStored = allLogs.length > 0 ? allLogs[allLogs.length - 1].timestamp : '';

        if (data.count !== lastLogCount || lastFetched !== lastStored) {
          allLogs = data.logs;
          lastLogCount = data.count;
          renderLogs();
        }

        // Set status connected
        statusBadge.className = "status-badge online";
        statusText.textContent = "Live Connected";
      } catch (err) {
        console.error('Error fetching logs:', err);
        statusBadge.className = "status-badge offline";
        statusText.textContent = "Disconnected";
      } finally {
        isFetching = false;
      }
    }

    // Clear Logs Buffer
    async function clearLogs() {
      if (!confirm('Are you sure you want to clear the server log buffer? This cannot be undone.')) return;
      try {
        const res = await fetch('/api/logs', { method: 'DELETE' });
        if (res.ok) {
          allLogs = [];
          lastLogCount = 0;
          renderLogs();
        }
      } catch (err) {
        alert('Failed to clear logs: ' + err.message);
      }
    }

    // Copy Logs to Clipboard
    function copyLogs() {
      let filtered = allLogs;
      if (activeFilter !== 'all') {
        filtered = filtered.filter(log => log.type === activeFilter);
      }
      if (searchQuery.trim() !== '') {
        const query = searchQuery.toLowerCase();
        filtered = filtered.filter(log => log.message.toLowerCase().includes(query));
      }

      const logText = filtered.map(log => \`[\${log.timestamp}] [\${log.type.toUpperCase()}] \${log.message}\`).join('\\n');
      navigator.clipboard.writeText(logText).then(() => {
        const originalText = btnCopy.innerHTML;
        btnCopy.innerHTML = '<span>✅</span> Copied!';
        setTimeout(() => {
          btnCopy.innerHTML = originalText;
        }, 1500);
      }).catch(err => {
        alert('Failed to copy logs: ' + err);
      });
    }

    // Set up Event Listeners
    filterButtons.forEach(btn => {
      btn.addEventListener('click', (e) => {
        filterButtons.forEach(b => b.classList.remove('active'));
        e.target.classList.add('active');
        activeFilter = e.target.getAttribute('data-level');
        renderLogs();
      });
    });

    searchInput.addEventListener('input', (e) => {
      searchQuery = e.target.value;
      renderLogs();
    });

    btnClear.addEventListener('click', clearLogs);
    btnCopy.addEventListener('click', copyLogs);

    // Admin Action Buttons Event Listeners
    const btnNotifyAll = document.getElementById('btn-notify-all');
    const btnCreateTask = document.getElementById('btn-create-task');
    const btnDeleteChats = document.getElementById('btn-delete-chats');

    async function triggerAdminAction(btn, url, confirmMsg = null) {
      if (confirmMsg && !confirm(confirmMsg)) return;

      const originalContent = btn.innerHTML;
      btn.disabled = true;
      btn.innerHTML = \`<span class="spinner"></span> Working...\`;

      try {
        const res = await fetch(url, { method: 'POST' });
        const data = await res.json();
        
        if (res.ok && data.success) {
          btn.innerHTML = \`<span>✅</span> Success\`;
          // Quick fetch to refresh terminal logs right away
          setTimeout(fetchLogs, 200);
        } else {
          btn.innerHTML = \`<span>❌</span> Failed\`;
          alert('Action failed: ' + (data.message || 'Unknown error'));
        }
      } catch (err) {
        btn.innerHTML = \`<span>❌</span> Error\`;
        alert('Request error: ' + err.message);
      } finally {
        setTimeout(() => {
          btn.disabled = false;
          btn.innerHTML = originalContent;
        }, 2000);
      }
    }

    btnNotifyAll.addEventListener('click', () => {
      triggerAdminAction(btnNotifyAll, '/api/test/notify-all');
    });

    btnCreateTask.addEventListener('click', () => {
      triggerAdminAction(btnCreateTask, '/api/test/create-demo-task');
    });

    btnDeleteChats.addEventListener('click', () => {
      triggerAdminAction(
        btnDeleteChats, 
        '/api/test/delete-chats', 
        '⚠️ DANGER: Are you sure you want to delete all messages and group chat history from the database? This cannot be undone.'
      );
    });

    // Initial load & Polling
    fetchLogs();
    setInterval(fetchLogs, 1500);
  </script>
</body>
</html>`;

export default app;
