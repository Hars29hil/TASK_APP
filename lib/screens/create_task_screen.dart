import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CreateTaskScreen extends StatefulWidget {
  const CreateTaskScreen({super.key});
  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final _supabase = Supabase.instance.client;
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _priority = 'medium';
  DateTime? _deadline;
  bool _isSubmitting = false;

  String get _backendUrl => dotenv.maybeGet('BACKEND_URL') ?? 'http://10.0.2.2:5000';

  // Steps list
  final List<Map<String, dynamic>> _steps = [
    {'title': '', 'controller': TextEditingController(), 'assigned_users': <Map<String, dynamic>>[]},
  ];

  // Leader
  Map<String, dynamic>? _leader;

  // User search
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  // stepIndex passed directly to _showUserSearchDialog
  final _userSearchCtrl = TextEditingController();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _userSearchCtrl.dispose();
    for (var s in _steps) { (s['controller'] as TextEditingController).dispose(); }
    super.dispose();
  }

  void _addStep() {
    setState(() {
      _steps.add({'title': '', 'controller': TextEditingController(), 'assigned_users': <Map<String, dynamic>>[]});
    });
  }

  void _removeStep(int index) {
    if (_steps.length <= 1) return;
    setState(() {
      ((_steps[index]['controller']) as TextEditingController).dispose();
      _steps.removeAt(index);
    });
  }

  Future<void> _searchUsers(String query) async {
    if (query.length < 2) { setState(() => _searchResults = []); return; }
    setState(() => _isSearching = true);
    try {
      final resp = await _supabase.from('profiles').select('id, full_name, email')
        .ilike('full_name', '%$query%').neq('id', _supabase.auth.currentUser?.id ?? '').limit(8);
      setState(() { _searchResults = List<Map<String, dynamic>>.from(resp); _isSearching = false; });
    } catch (e) {
      setState(() => _isSearching = false);
    }
  }

  void _showUserSearchDialog({int? stepIndex}) {
    _userSearchCtrl.clear();
    _searchResults = [];
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setModalState) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.6,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(stepIndex != null ? "Assign User to Step ${stepIndex + 1}" : "Select Leader", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _userSearchCtrl,
                decoration: InputDecoration(
                  hintText: "Search users...", prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                  filled: true, fillColor: Colors.grey[50],
                ),
                onChanged: (v) async {
                  await _searchUsers(v);
                  setModalState(() {});
                },
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (ctx, i) {
                      final user = _searchResults[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=${user['id']}'),
                        ),
                        title: Text(user['full_name'] ?? 'Unknown'),
                        subtitle: Text(user['email'] ?? '', style: const TextStyle(fontSize: 12)),
                        onTap: () {
                          setState(() {
                            if (stepIndex != null) {
                              final users = _steps[stepIndex]['assigned_users'] as List<Map<String, dynamic>>;
                              if (!users.any((u) => u['id'] == user['id'])) users.add(user);
                            } else {
                              _leader = user;
                            }
                          });
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
            ),
          ]),
        );
      }),
    );
  }

  Future<void> _pickDeadline() async {
    final date = await showDatePicker(
      context: context, firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF4A00E0))),
        child: child!,
      ),
    );
    if (date != null) setState(() => _deadline = date);
  }

  Future<void> _submitTask() async {
    // Validate
    if (_titleCtrl.text.trim().isEmpty) {
      _showSnack("Please enter a task title"); return;
    }
    for (int i = 0; i < _steps.length; i++) {
      final ctrl = _steps[i]['controller'] as TextEditingController;
      if (ctrl.text.trim().isEmpty) { _showSnack("Please enter title for Step ${i + 1}"); return; }
    }

    setState(() => _isSubmitting = true);

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception("Not logged in");

      final stepsPayload = _steps.map((s) {
        final ctrl = s['controller'] as TextEditingController;
        final users = s['assigned_users'] as List<Map<String, dynamic>>;
        return {
          'title': ctrl.text.trim(),
          'assigned_users': users.map((u) => u['id']).toList(),
        };
      }).toList();

      // Collect all unique member IDs
      final memberIds = <String>{};
      for (var s in stepsPayload) {
        for (var uid in (s['assigned_users'] as List)) {
          memberIds.add(uid);
        }
      }
      if (_leader != null) memberIds.add(_leader!['id']);

      final body = {
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'priority': _priority,
        'deadline': _deadline?.toIso8601String(),
        'created_by': userId,
        'steps': stepsPayload,
        'members': memberIds.toList(),
        'leader_id': _leader?['id'],
      };

      final resp = await http.post(
        Uri.parse('$_backendUrl/tasks'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      final data = jsonDecode(resp.body);
      if (data['success'] == true) {
        if (mounted) { Navigator.pop(context, true); }
      } else {
        _showSnack(data['message'] ?? "Failed to create task");
      }
    } catch (e) {
      _showSnack("Error: $e");
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: const Color(0xFF4A00E0)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.close_rounded, color: Colors.black87), onPressed: () => Navigator.pop(context)),
        title: const Text("Create Task", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Title
          _label("Task Title"),
          _inputField(_titleCtrl, "e.g. Mobile App Launch", Icons.title_rounded),
          const SizedBox(height: 18),

          // Description
          _label("Description"),
          _inputField(_descCtrl, "Describe the task...", Icons.description_rounded, maxLines: 3),
          const SizedBox(height: 18),

          // Priority
          _label("Priority"),
          _buildPrioritySelector(),
          const SizedBox(height: 18),

          // Deadline
          _label("Deadline"),
          GestureDetector(
            onTap: _pickDeadline,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.withValues(alpha: 0.2))),
              child: Row(children: [
                const Icon(Icons.calendar_today_rounded, color: Color(0xFF4A00E0), size: 20),
                const SizedBox(width: 12),
                Text(_deadline != null ? "${_deadline!.day}/${_deadline!.month}/${_deadline!.year}" : "Select deadline", style: TextStyle(color: _deadline != null ? Colors.black87 : Colors.grey)),
              ]),
            ),
          ),
          const SizedBox(height: 18),

          // Leader
          _label("Leader (Optional)"),
          GestureDetector(
            onTap: () => _showUserSearchDialog(),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.withValues(alpha: 0.2))),
              child: Row(children: [
                const Icon(Icons.star_rounded, color: Color(0xFFFF9500), size: 20),
                const SizedBox(width: 12),
                Text(_leader != null ? "⭐ ${_leader!['full_name']}" : "Assign a leader", style: TextStyle(color: _leader != null ? Colors.black87 : Colors.grey)),
                const Spacer(),
                if (_leader != null) GestureDetector(
                  onTap: () => setState(() => _leader = null),
                  child: const Icon(Icons.close, size: 18, color: Colors.grey),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 24),

          // Steps
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _label("Steps"),
            TextButton.icon(onPressed: _addStep, icon: const Icon(Icons.add_circle_rounded, size: 20, color: Color(0xFF4A00E0)), label: const Text("Add Step", style: TextStyle(color: Color(0xFF4A00E0), fontWeight: FontWeight.bold))),
          ]),
          const SizedBox(height: 8),
          ..._steps.asMap().entries.map((e) => _buildStepCard(e.key)),
          const SizedBox(height: 30),

          // Submit
          SizedBox(
            width: double.infinity, height: 56,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitTask,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A00E0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                elevation: 8,
                shadowColor: const Color(0xFF4A00E0).withValues(alpha: 0.4),
              ),
              child: _isSubmitting
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text("Create Task", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E))),
  );

  Widget _inputField(TextEditingController ctrl, String hint, IconData icon, {int maxLines = 1}) => Container(
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.withValues(alpha: 0.2))),
    child: TextField(
      controller: ctrl, maxLines: maxLines,
      decoration: InputDecoration(hintText: hint, prefixIcon: Icon(icon, color: const Color(0xFF4A00E0), size: 20), border: InputBorder.none, contentPadding: const EdgeInsets.all(16)),
    ),
  );

  Widget _buildPrioritySelector() => Row(
    children: ['low', 'medium', 'high', 'urgent'].map((p) {
      final sel = _priority == p;
      final color = switch (p) { 'urgent' => const Color(0xFFFF3B30), 'high' => const Color(0xFFFF9500), 'low' => const Color(0xFF34C759), _ => const Color(0xFF007AFF) };
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _priority = p),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: sel ? color : Colors.white, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: sel ? color : Colors.grey.withValues(alpha: 0.2)),
              boxShadow: sel ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))] : [],
            ),
            child: Text(p[0].toUpperCase() + p.substring(1), textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: sel ? Colors.white : Colors.grey[600])),
          ),
        ),
      );
    }).toList(),
  );

  Widget _buildStepCard(int index) {
    final step = _steps[index];
    final ctrl = step['controller'] as TextEditingController;
    final users = step['assigned_users'] as List<Map<String, dynamic>>;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF4A00E0).withValues(alpha: 0.1)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)]), borderRadius: BorderRadius.circular(8)),
            child: Center(child: Text("${index + 1}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
          ),
          const SizedBox(width: 10),
          Expanded(child: TextField(controller: ctrl, decoration: const InputDecoration(hintText: "Step title...", border: InputBorder.none, isDense: true), style: const TextStyle(fontWeight: FontWeight.w600))),
          if (_steps.length > 1) GestureDetector(onTap: () => _removeStep(index), child: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 22)),
        ]),
        const Divider(height: 20),
        // Assigned users
        Wrap(spacing: 6, runSpacing: 6, children: [
          ...users.map((u) => Chip(
            avatar: CircleAvatar(backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=${u['id']}'), radius: 12),
            label: Text(u['full_name'] ?? '', style: const TextStyle(fontSize: 12)),
            deleteIcon: const Icon(Icons.close, size: 14),
            onDeleted: () => setState(() => users.removeWhere((x) => x['id'] == u['id'])),
            backgroundColor: const Color(0xFF4A00E0).withValues(alpha: 0.08),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          )),
          ActionChip(
            avatar: const Icon(Icons.person_add_rounded, size: 16, color: Color(0xFF4A00E0)),
            label: const Text("Assign", style: TextStyle(fontSize: 12, color: Color(0xFF4A00E0))),
            onPressed: () => _showUserSearchDialog(stepIndex: index),
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: const Color(0xFF4A00E0).withValues(alpha: 0.3))),
          ),
        ]),
      ]),
    );
  }
}
