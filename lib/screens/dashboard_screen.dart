import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../models/project.dart';
import '../services/task_service.dart';
import 'home_screen.dart';
import 'task_list_screen.dart';
import 'chat_list_screen.dart';
import 'activity_feed_screen.dart';
import 'create_task_screen.dart';
import 'login_screen.dart';

/// App Shell — Root screen with a floating vertical dock on the right.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;
  final _supabase = Supabase.instance.client;
  final _service = TaskService.instance;

  List<Project> _projects = [];
  bool _isLoading = true;
  RealtimeChannel? _taskChannel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setUserStatus(true);
    _fetchProjects();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _setUserStatus(false);
    _taskChannel?.unsubscribe();
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
        await _supabase.from('profiles').update({
          'is_online': isOnline,
          'last_seen': DateTime.now().toIso8601String(),
        }).eq('id', userId);
      } catch (e) {
        debugPrint("Error updating user status: $e");
      }
    }
  }

  void _subscribeRealtime() {
    _taskChannel = _supabase
        .channel('dashboard-updates')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'tasks',
          callback: (_) => _fetchProjects(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'task_steps',
          callback: (_) => _fetchProjects(),
        )
        .subscribe();
  }

  Future<void> _fetchProjects() async {
    final projects = await _service.fetchProjects();
    if (mounted) {
      setState(() {
        _projects = projects;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmWhite,
      body: Stack(
        children: [
          // Content
          Positioned.fill(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                HomeScreen(
                  projects: _projects,
                  isLoading: _isLoading,
                  onRefresh: _fetchProjects,
                ),
                const TaskListScreen(),
                const ChatListScreen(),
                const ActivityFeedScreen(),
              ],
            ),
          ),

          // Floating Bottom Dock
          Positioned(
            left: 24,
            right: 24,
            bottom: 24,
            child: _buildBottomDock(),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomDock() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.ink.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(32),
        boxShadow: AppShadows.medium,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _dockItem(Icons.folder_rounded, targetIndex: 1), // Spaces / Tasks
          _dockItem(Icons.chat_bubble_rounded, targetIndex: 2), // Chat
          _dockItem(Icons.home_rounded, targetIndex: 0), // Dashboard (Center)
          _dockItem(Icons.notifications_rounded, targetIndex: 3), // Activity
          _dockItem(Icons.person_rounded, targetIndex: -1, isProfile: true), // Profile
        ],
      ),
    );
  }

  Widget _dockItem(IconData icon, {required int targetIndex, bool isProfile = false}) {
    final isActive = !isProfile && _selectedIndex == targetIndex;

    return GestureDetector(
      onTap: () {
        if (isProfile) {
          _showProfileModal();
        } else {
          setState(() => _selectedIndex = targetIndex);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isActive ? AppColors.electricBlue : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
          child: Icon(
            icon,
            key: ValueKey<bool>(isActive),
            color: isActive ? Colors.white : AppColors.textTertiary,
            size: 24,
          ),
        ),
      ),
    );
  }

  void _showProfileModal() {
    // ... basic logout modal ...
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Profile',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.add_circle_rounded, color: AppColors.electricBlue),
                title: const Text('Create New Task'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreateTaskScreen()),
                  ).then((_) => _fetchProjects());
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout_rounded, color: AppColors.warning),
                title: const Text('Sign Out'),
                onTap: () async {
                  await _supabase.auth.signOut();
                  if (mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
