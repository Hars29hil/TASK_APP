import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_detail_screen.dart';
import 'task_chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with TickerProviderStateMixin {
  late AnimationController _staggerController;
  final TextEditingController _searchController = TextEditingController();
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _allItems = [];
  String _activeTab = "All";
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();

    // Initial fetch
    _fetchData("");
  }

  Future<void> _fetchData(String query) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        setState(() => _isLoading = false);
        return;
      }

      // 1. Fetch Users (1-on-1)
      // We search both full_name and email to be safe
      var userQuery = _supabase.from('profiles').select();
      
      if (query.isNotEmpty) {
        userQuery = userQuery.or('full_name.ilike.%$query%,email.ilike.%$query%');
      }

      final userResponse = await userQuery
          .neq('id', currentUserId)
          .limit(20);

      // 2. Fetch Task Groups (Separated to avoid 500 join errors)
      final membershipResponse = await _supabase
          .from('task_members')
          .select('task_id, role')
          .eq('user_id', currentUserId);

      List<Map<String, dynamic>> items = [];

      // Add Users
      for (var u in userResponse) {
        items.add({
          ...u, 
          'isGroup': false,
          'display_name': (u['full_name'] != null && u['full_name'].toString().isNotEmpty) 
              ? u['full_name'] 
              : u['email']?.toString().split('@')[0] ?? "User"
        });
      }

      // Add Tasks
      if (membershipResponse.isNotEmpty) {
        final taskIds = membershipResponse.map((m) => m['task_id']).toList();
        final tasksDetails = await _supabase
            .from('tasks')
            .select('id, title, status')
            .inFilter('id', taskIds);

        for (var task in tasksDetails) {
          final membership = membershipResponse.firstWhere((m) => m['task_id'] == task['id']);
          if (query.isEmpty || task['title'].toString().toLowerCase().contains(query.toLowerCase())) {
            items.add({
              'id': task['id'],
              'full_name': task['title'],
              'display_name': task['title'],
              'status': task['status'],
              'isGroup': true,
              'role': membership['role'],
            });
          }
        }
      }

      if (mounted) {
        setState(() {
          _allItems = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
      debugPrint("Error fetching chat data: $e");
    }
  }

  @override
  void dispose() {
    _staggerController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Dynamic Gradient Background
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.blue.withValues(alpha: 0.05),
                    Colors.purple.withValues(alpha: 0.05),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    _buildSearchBar(),
                    _buildTabs(),
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : RefreshIndicator(
                              onRefresh: () => _fetchData(""),
                              color: const Color(0xFF4A00E0),
                              child: _buildChatList(),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "Chats",
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),
          Row(
            children: [
              _buildIconButton(Icons.search_rounded),
              const SizedBox(width: 10),
              _buildIconButton(Icons.edit_note_rounded, isPrimary: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton(IconData icon, {bool isPrimary = false}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isPrimary ? const Color(0xFF4A00E0) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: isPrimary
                ? const Color(0xFF4A00E0).withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Icon(
        icon,
        color: isPrimary ? Colors.white : Colors.black87,
        size: 22,
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 20,
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (val) => _fetchData(val), // Instant search as you type
          decoration: const InputDecoration(
            hintText: "Search name or task...",
            border: InputBorder.none,
            icon: Icon(Icons.search, color: Color(0xFF4A00E0)),
            suffixIcon: Icon(Icons.tune_rounded, color: Colors.grey),
          ),
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _tabItem("All", _activeTab == "All"),
          _tabItem("Groups", _activeTab == "Groups"),
        ],
      ),
    );
  }

  Widget _tabItem(String label, bool isActive, {int? count}) {
    return GestureDetector(
      onTap: () => setState(() => _activeTab = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF4A00E0)
              : Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Color(0xFF8E2DE2),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  count.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChatList() {
    List<Map<String, dynamic>> filtered = _allItems;
    if (_activeTab == "Groups") {
      filtered = _allItems.where((i) => i['isGroup'] == true).toList();
    } else if (_activeTab == "All") {
      filtered = _allItems;
    } else {
      // For demo, just return empty for others
      filtered = [];
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 40, color: Colors.red),
              const SizedBox(height: 10),
              Text("Database Error: $_errorMessage", 
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 12)),
              TextButton(onPressed: () => _fetchData(""), child: const Text("Try Again"))
            ],
          ),
        ),
      );
    }

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 50, color: Colors.grey[300]),
            const SizedBox(height: 10),
            Text("No chats found", style: TextStyle(color: Colors.grey[400])),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        return _buildChatTile(filtered[index]);
      },
    );
  }

  Widget _buildChatTile(Map<String, dynamic> item) {
    final bool isGroup = item['isGroup'] ?? false;
    
    return GestureDetector(
      onTap: () {
        if (isGroup) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TaskChatScreen(
                taskId: item['id'],
                taskTitle: item['full_name'],
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            PageRouteBuilder(
              transitionDuration: const Duration(milliseconds: 600),
              pageBuilder: (context, animation, secondaryAnimation) =>
                  ChatDetailScreen(
                userId: item['id'],
                userName: item['display_name'] ?? "Unknown User",
              ),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Stack(
              children: [
                Hero(
                  tag: 'chat_avatar_${item['id']}_${isGroup ? 'group' : 'user'}',
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: isGroup ? const Color(0xFF4A00E0) : Colors.grey[200],
                    backgroundImage: isGroup 
                      ? null 
                      : NetworkImage('https://i.pravatar.cc/150?u=${item['id']}'),
                    child: isGroup 
                      ? const Icon(Icons.groups_rounded, color: Colors.white, size: 28)
                      : null,
                  ),
                ),
                if (!isGroup) Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            item['display_name'] ?? "Unknown",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (isGroup) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4A00E0).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: const Text("TASK", style: TextStyle(color: Color(0xFF4A00E0), fontSize: 9, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        "Now",
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isGroup ? "Group chat for this task..." : "Tap to start chatting...",
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
