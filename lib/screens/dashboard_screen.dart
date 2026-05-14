import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_list_screen.dart';
import 'task_list_screen.dart';
import 'create_task_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  int _selectedIndex = 1; // Default to DashBoard (Index 1)
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setUserStatus(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _setUserStatus(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setUserStatus(true);
    } else {
      _setUserStatus(false);
    }
  }

  Future<void> _setUserStatus(bool isOnline) async {
    if (!mounted) return;
    final userId = _supabase.auth.currentUser?.id;
    if (userId != null) {
      try {
        await _supabase
            .from('profiles')
            .update({
              'is_online': isOnline,
              'last_seen': DateTime.now().toIso8601String(),
            })
            .eq('id', userId);
        if (mounted) debugPrint("User status updated: isOnline=$isOnline");
      } catch (e) {
        if (mounted) debugPrint("Error updating user status: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: _selectedIndex == 1 ? _buildAppBar() : null,
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex,
            children: [
              _buildTaskCenter(), // Tasks (Index 0)
              _buildDashboardContent(), // DashBoard (Index 1)
              const ChatListScreen(), // Chat (Index 2)
            ],
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: _buildBottomNavBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGreetings(),
          const SizedBox(height: 25),
          _buildStatsGrid(),
          const SizedBox(height: 25),
          _buildTaskOverview(),
          const SizedBox(height: 25),
          _buildUpcomingTasks(),
        ],
      ),
    );
  }

  Widget _buildTaskCenter() {
    return const TaskListScreen();
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
            ),
          ],
        ),
        child: const Icon(Icons.menu, color: Colors.black87),
      ),
      title: const Text(
        "Dashboard",
        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_none, color: Colors.black87),
          onPressed: () {},
        ),
        const Padding(
          padding: EdgeInsets.only(right: 15),
          child: CircleAvatar(
            radius: 18,
            backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=a'),
          ),
        ),
      ],
    );
  }

  Widget _buildGreetings() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Good Morning! 👋",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 5),
            Text(
              "User ID: ${Supabase.instance.client.auth.currentUser?.id ?? 'Not Logged In'}",
              style: TextStyle(
                color: Colors.blueAccent,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 2),
            Text(
              "Here's what's happening today.",
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
            ),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4A00E0).withValues(alpha: 0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateTaskScreen()));
            },
            child: Row(
              children: const [
                Icon(Icons.add, color: Colors.white, size: 20),
                SizedBox(width: 5),
                Text(
                  "New Task",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      childAspectRatio: 1.2,
      children: [
        _buildStatCard("Total Tasks", "--", Icons.assignment, Colors.blue),
        _buildStatCard("Completed", "--", Icons.check_circle, Colors.green),
        _buildStatCard("In Progress", "--", Icons.pending, Colors.orange),
        _buildStatCard("Overdue", "--", Icons.error, Colors.red),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Icon(Icons.show_chart, color: Colors.grey, size: 20),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTaskOverview() {
    return Container(
      padding: const EdgeInsets.all(20),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Tasks Overview",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text("This Week", style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 30),
          SizedBox(
            height: 150,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (index) => _buildBar(index)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBar(int index) {
    double heightValue = 40.0 + (index * 15.0) % 80.0;
    return Column(
      children: [
        Expanded(
          child: Container(
            width: 15,
            height: heightValue,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: index == 4
                    ? [const Color(0xFF8E2DE2), const Color(0xFF4A00E0)]
                    : [Colors.grey[200]!, Colors.grey[100]!],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          ['M', 'T', 'W', 'T', 'F', 'S', 'S'][index],
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildUpcomingTasks() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Upcoming Tasks",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 15),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
          ),
          child: Column(
            children: [
              Icon(
                Icons.assignment_turned_in_outlined,
                size: 50,
                color: Colors.blue.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 15),
              const Text(
                "No upcoming tasks",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Text(
                "You're all caught up!",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(0, Icons.task_alt_rounded, "Tasks"),
                _navItem(1, Icons.dashboard_rounded, "DashBoard"),
                _navItem(2, Icons.chat_bubble_rounded, "Chat"),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    bool isActive = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: Colors.transparent, // Ensure hit test works
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: isActive ? 1.2 : 1.0,
              duration: const Duration(milliseconds: 400),
              child: Icon(
                icon,
                color: isActive ? const Color(0xFF4A00E0) : Colors.grey[400],
                size: 28,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? const Color(0xFF4A00E0) : Colors.transparent,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
