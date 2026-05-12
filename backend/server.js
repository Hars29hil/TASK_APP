import express from "express";
import cors from "cors";
import dotenv from "dotenv";
import nodemailer from "nodemailer";
import { createClient } from '@supabase/supabase-js';
import { sendPushNotification } from "./firebase.js";

// Load environment variables from the main project folder
dotenv.config({ path: '../.env' });

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
const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_ROLE_KEY
);

// ======================================
// TEMP OTP STORAGE
// (Use DB/Redis in production)
// ======================================
const otpStore = {};

// ======================================
// NODEMAILER CONFIG
// ======================================
const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASS,
  },
});

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
      from: process.env.EMAIL_USER,
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

        // 5. Create steps (first step is active, rest are pending)
        const stepInserts = steps.map((step, index) => ({
            task_id: task.id,
            step_number: index + 1,
            step_title: step.title,
            description: step.description || null,
            status: index === 0 ? 'active' : 'pending',
        }));

        const { data: createdSteps, error: stepError } = await supabase
            .from('task_steps')
            .insert(stepInserts)
            .select()
            .order('step_number', { ascending: true });
        if (stepError) throw stepError;

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
                task_steps (id, step_number, step_title, status, completed_at),
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
                    id, step_number, step_title, description, status, completed_at, completed_by
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
// COMPLETE STEP — DEPENDENCY ENGINE 🔥
// ======================================
app.post("/tasks/:taskId/complete-step", async (req, res) => {
    try {
        const { taskId } = req.params;
        const { user_id, step_id } = req.body;

        if (!user_id || !step_id) {
            return res.status(400).json({ success: false, message: "user_id and step_id are required" });
        }

        // 1. Verify the step exists and is active
        const { data: step, error: stepError } = await supabase
            .from('task_steps')
            .select('*')
            .eq('id', step_id)
            .eq('task_id', taskId)
            .single();

        if (stepError || !step) {
            return res.status(404).json({ success: false, message: "Step not found" });
        }

        if (step.status !== 'active') {
            return res.status(400).json({ success: false, message: "This step is not currently active" });
        }

        // 2. Verify user is assigned to this step
        const assignedUsers = await getStepAssignedUsers(step_id);
        // Also allow admin/leader to complete any step
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

        // 3. Mark current step as completed
        const { error: updateError } = await supabase
            .from('task_steps')
            .update({
                status: 'completed',
                completed_at: new Date().toISOString(),
                completed_by: user_id,
            })
            .eq('id', step_id);

        if (updateError) throw updateError;

        // 4. Check for next step
        const { data: nextStep } = await supabase
            .from('task_steps')
            .select('*')
            .eq('task_id', taskId)
            .eq('step_number', step.step_number + 1)
            .single();

        // Get task title for notifications
        const { data: task } = await supabase
            .from('tasks')
            .select('title')
            .eq('id', taskId)
            .single();

        const taskTitle = task ? task.title : 'Task';

        if (nextStep) {
            // 5a. Activate next step
            await supabase
                .from('task_steps')
                .update({ status: 'active' })
                .eq('id', nextStep.id);

            // Notify next step's assigned users
            const nextStepUsers = await getStepAssignedUsers(nextStep.id);
            for (const uid of nextStepUsers) {
                await sendTaskNotification(
                    uid,
                    taskId,
                    'step_activated',
                    "Your Turn!",
                    `Step "${nextStep.step_title}" is now active in ${taskTitle}`
                );
            }

            // Notify in group chat
            const { data: completedByUser } = await supabase
                .from('profiles')
                .select('full_name')
                .eq('id', user_id)
                .single();

            await supabase.from('task_group_messages').insert({
                task_id: taskId,
                sender_id: user_id,
                content: `✅ ${completedByUser?.full_name || 'Someone'} completed "${step.step_title}". Next up: "${nextStep.step_title}"`,
            });

            console.log(`🔄 Step ${step.step_number} completed → Step ${nextStep.step_number} activated`);

            res.json({
                success: true,
                message: "Step completed, next step activated",
                completed_step: step.step_number,
                next_step: nextStep.step_number,
                task_completed: false,
            });

        } else {
            // 5b. No more steps — Task is complete!
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
                sender_id: user_id,
                content: `🎉 All steps completed! Task "${taskTitle}" is now finished!`,
            });

            console.log(`🏁 Task "${taskTitle}" COMPLETED!`);

            res.json({
                success: true,
                message: "Task completed!",
                completed_step: step.step_number,
                task_completed: true,
            });
        }

    } catch (error) {
        console.error("❌ Complete step error:", error);
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
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
