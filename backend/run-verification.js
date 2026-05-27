import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
import path from 'path';

dotenv.config({ path: '../.env' });

const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_ROLE_KEY
);

const PORT = process.env.PORT || 5000;
const BASE_URL = `http://localhost:${PORT}`;

async function runTests() {
    console.log("⚡ Starting API workflow verification tests...\n");

    try {
        // 1. Fetch profiles to act as users
        const { data: profiles, error: pError } = await supabase
            .from('profiles')
            .select('id, full_name, email')
            .limit(3);

        if (pError || !profiles || profiles.length < 2) {
            throw new Error(`Need at least 2 profiles in database. Found error: ${pError?.message}`);
        }

        const adminUser = profiles[0]; // will create task (role: admin)
        const leaderUser = profiles[1] || adminUser; // leader role
        const memberUser = profiles[2] || adminUser; // member role

        console.log(`Roles mapping:`);
        console.log(`- Admin: ${adminUser.full_name} (${adminUser.id})`);
        console.log(`- Leader: ${leaderUser.full_name} (${leaderUser.id})`);
        console.log(`- Member: ${memberUser.full_name} (${memberUser.id})`);

        // 2. Create Task with sequential steps
        console.log("\n--- Creating Task ---");
        const createTaskPayload = {
            title: "Test Task Verification",
            description: "Testing cascading deadlines and status flows",
            priority: "high",
            created_by: adminUser.id,
            leader_id: leaderUser.id,
            members: [adminUser.id, leaderUser.id, memberUser.id],
            steps: [
                { title: "Step 1: Design", description: "Design UI", duration_days: 3, assigned_users: [memberUser.id] },
                { title: "Step 2: Code", description: "Write Flutter UI", duration_days: 2, assigned_users: [memberUser.id] },
                { title: "Step 3: QA", description: "Verify functionality", duration_days: 1, assigned_users: [adminUser.id] }
            ]
        };

        const createResp = await fetch(`${BASE_URL}/tasks`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(createTaskPayload)
        });

        if (!createResp.ok) {
            throw new Error(`Failed to create task: ${createResp.statusText}`);
        }

        const createData = await createResp.json();
        if (!createData.success) {
            throw new Error(`Task creation returned success: false: ${createData.message}`);
        }

        const task = createData.task;
        console.log(`✅ Task created successfully. ID: ${task.id}`);
        console.log(`   Task overall deadline: ${task.deadline}`);

        // Verify steps initial state
        const steps = task.steps;
        console.log("   Steps:");
        steps.forEach(s => {
            console.log(`   - Step ${s.step_number}: ${s.step_title} (Status: ${s.status}, Duration: ${s.duration_days} days, Deadline: ${s.deadline})`);
        });

        if (steps[0].status !== 'ready') throw new Error("Step 1 status should be 'ready'");
        if (steps[1].status !== 'pending') throw new Error("Step 2 status should be 'pending'");

        const step1Id = steps[0].id;
        const step2Id = steps[1].id;

        // 3. Start Task step
        console.log("\n--- Starting Step 1 ---");
        const startResp = await fetch(`${BASE_URL}/tasks/${task.id}/steps/${step1Id}/start`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ user_id: memberUser.id })
        });
        const startData = await startResp.json();
        console.log(`✅ Start step response:`, startData);
        if (!startData.success) throw new Error("Failed to start step 1");

        // Verify step 1 state is now 'in_progress'
        const detailResp1 = await fetch(`${BASE_URL}/tasks/detail/${task.id}`);
        const detailData1 = await detailResp1.json();
        const updatedStep1 = detailData1.task.task_steps.find(s => s.id === step1Id);
        console.log(`   Step 1 status is now: ${updatedStep1.status} (Expected: in_progress)`);
        if (updatedStep1.status !== 'in_progress') throw new Error("Step 1 status should be 'in_progress'");

        // 4. Request Deadline Extension
        console.log("\n--- Requesting extension for Step 1 ---");
        const extReqResp = await fetch(`${BASE_URL}/tasks/${task.id}/steps/${step1Id}/request-extension`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                user_id: memberUser.id,
                days_requested: 3,
                reason: "We need more time to polish designs"
            })
        });
        const extReqData = await extReqResp.json();
        console.log(`✅ Extension request response:`, extReqData);
        if (!extReqData.success) throw new Error("Failed to request extension");

        const extensionId = extReqData.request.id;

        // 5. Resolve (Approve) Deadline Extension
        console.log("\n--- Resolving (Approving) extension request ---");
        const resolveResp = await fetch(`${BASE_URL}/tasks/${task.id}/extensions/${extensionId}/resolve`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                user_id: leaderUser.id,
                status: "approved"
            })
        });
        const resolveData = await resolveResp.json();
        console.log(`✅ Extension resolution response:`, resolveData);
        if (!resolveData.success) throw new Error("Failed to resolve extension");

        // Verify Cascading deadlines: Step 1, Step 2, Step 3, and overall Task deadlines should all increase by 3 days!
        const detailResp2 = await fetch(`${BASE_URL}/tasks/detail/${task.id}`);
        const detailData2 = await detailResp2.json();
        const finalTask = detailData2.task;
        const finalSteps = finalTask.task_steps.sort((a,b) => a.step_number - b.step_number);

        console.log("\n🔍 Verifying Cascading Deadlines (+3 days shift):");
        const originalTaskDl = new Date(task.deadline);
        const shiftedTaskDl = new Date(finalTask.deadline);
        const taskShiftDays = (shiftedTaskDl - originalTaskDl) / (1000 * 60 * 60 * 24);
        console.log(`- Task Deadline: ${task.deadline} -> ${finalTask.deadline} (Shift: +${taskShiftDays} days)`);
        if (Math.round(taskShiftDays) !== 3) throw new Error("Task deadline should have shifted by exactly 3 days");

        for (let i = 0; i < steps.length; i++) {
            const origDl = new Date(steps[i].deadline);
            const newDl = new Date(finalSteps[i].deadline);
            const shiftDays = (newDl - origDl) / (1000 * 60 * 60 * 24);
            console.log(`- Step ${i+1} Deadline: ${steps[i].deadline} -> ${finalSteps[i].deadline} (Shift: +${shiftDays} days)`);
            if (Math.round(shiftDays) !== 3) throw new Error(`Step ${i+1} deadline should have shifted by exactly 3 days`);
        }
        console.log("✅ Cascading deadlines verified successfully!");

        // 6. Block step
        console.log("\n--- Blocking Step 1 ---");
        const blockResp = await fetch(`${BASE_URL}/tasks/${task.id}/steps/${step1Id}/block`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ user_id: memberUser.id, reason: "Awaiting client feedback on color palette" })
        });
        const blockData = await blockResp.json();
        console.log(`✅ Block step response:`, blockData);
        if (!blockData.success) throw new Error("Failed to block step 1");

        // Verify status is blocked
        const detailResp3 = await fetch(`${BASE_URL}/tasks/detail/${task.id}`);
        const detailData3 = await detailResp3.json();
        const step1Blocked = detailData3.task.task_steps.find(s => s.id === step1Id);
        console.log(`   Step 1 status is now: ${step1Blocked.status} (Expected: blocked), Reason: "${step1Blocked.blocked_reason}"`);
        if (step1Blocked.status !== 'blocked') throw new Error("Step 1 status should be 'blocked'");

        // 7. Unblock step
        console.log("\n--- Unblocking Step 1 ---");
        const unblockResp = await fetch(`${BASE_URL}/tasks/${task.id}/steps/${step1Id}/unblock`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ user_id: memberUser.id })
        });
        const unblockData = await unblockResp.json();
        console.log(`✅ Unblock step response:`, unblockData);
        if (!unblockData.success) throw new Error("Failed to unblock step 1");
        console.log(`   Step 1 status restored to: ${unblockData.status}`);

        // 8. Complete step as a Member (should transition to waiting_approval)
        console.log("\n--- Completing Step 1 as a Member ---");
        const completeResp = await fetch(`${BASE_URL}/tasks/${task.id}/complete-step`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ user_id: memberUser.id, step_id: step1Id })
        });
        const completeData = await completeResp.json();
        console.log(`✅ Complete step response:`, completeData);
        if (!completeData.success) throw new Error("Failed to submit step completion");
        console.log(`   Step 1 status is now: ${completeData.status} (Expected: waiting_approval)`);
        if (completeData.status !== 'waiting_approval') throw new Error("Step 1 should be in waiting_approval");

        // 9. Approve Completion as a Leader
        console.log("\n--- Approving Step 1 completion as Leader ---");
        const approveResp = await fetch(`${BASE_URL}/tasks/${task.id}/steps/${step1Id}/approve-completion`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ user_id: leaderUser.id })
        });
        const approveData = await approveResp.json();
        console.log(`✅ Approve completion response:`, approveData);
        if (!approveData.success) throw new Error("Failed to approve completion");

        // Verify Step 1 is completed and Step 2 is ready
        const detailResp4 = await fetch(`${BASE_URL}/tasks/detail/${task.id}`);
        const detailData4 = await detailResp4.json();
        const stepsAfterApproval = detailData4.task.task_steps;
        const s1 = stepsAfterApproval.find(s => s.id === step1Id);
        const s2 = stepsAfterApproval.find(s => s.id === step2Id);

        console.log(`   Step 1 status after leader approval: ${s1.status} (Expected: completed)`);
        console.log(`   Step 2 status after leader approval: ${s2.status} (Expected: ready)`);
        if (s1.status !== 'completed') throw new Error("Step 1 should be completed");
        if (s2.status !== 'ready') throw new Error("Step 2 should be ready");

        // 10. Leader permissions limits: Leader cannot remove Admin member
        console.log("\n--- Testing Leader Permissions Limits ---");
        const deleteMemberResp = await fetch(`${BASE_URL}/tasks/${task.id}/members`, {
            method: 'DELETE',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                user_id: leaderUser.id,       // Leader making request
                target_user_id: adminUser.id   // Target is Admin
            })
        });
        const deleteMemberData = await deleteMemberResp.json();
        console.log(`✅ Remove member response (Leader trying to remove Admin):`, deleteMemberData);
        if (deleteMemberResp.status === 403 || deleteMemberData.success === false) {
            console.log("   Successfully blocked Leader from removing Admin!");
        } else {
            throw new Error("Leader was incorrectly allowed to remove Admin member");
        }

        // Clean up: delete task
        console.log("\n--- Cleaning up task ---");
        const deleteResp = await fetch(`${BASE_URL}/tasks/${task.id}`, {
            method: 'DELETE',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ user_id: adminUser.id })
        });
        const deleteData = await deleteResp.json();
        console.log(`✅ Cleaned up test task:`, deleteData);

        console.log("\n🎉 ALL TESTS PASSED SUCCESSFULLY! 🚀");
        process.exit(0);

    } catch (err) {
        console.error("\n❌ TEST FAILURE:", err);
        process.exit(1);
    }
}

runTests();
