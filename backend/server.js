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

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
