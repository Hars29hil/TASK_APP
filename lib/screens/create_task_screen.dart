import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

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

  String get _backendUrl {
    if (kIsWeb) {
      final envUrl = dotenv.maybeGet('BACKEND_URL');
      if (envUrl != null && envUrl.contains('http') && !envUrl.contains('10.0.2.2')) {
        return envUrl;
      }
      return 'http://localhost:5000';
    }
    final envUrl = dotenv.maybeGet('BACKEND_URL');
    if (envUrl != null && envUrl.isNotEmpty) return envUrl;
    
    if (Theme.of(context).platform == TargetPlatform.android) {
      return 'http://10.0.2.2:5000';
    }
    return 'http://localhost:5000';
  }

  final List<Map<String, dynamic>> _steps = [
    {
      'title': '',
      'controller': TextEditingController(),
      'duration_controller': TextEditingController(text: '2'),
      'assigned_users': <Map<String, dynamic>>[]
    },
  ];

  Map<String, dynamic>? _leader;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  final _userSearchCtrl = TextEditingController();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _userSearchCtrl.dispose();
    for (var s in _steps) {
      (s['controller'] as TextEditingController).dispose();
      (s['duration_controller'] as TextEditingController).dispose();
    }
    super.dispose();
  }

  void _addStep() {
    setState(() {
      _steps.add({
        'title': '',
        'controller': TextEditingController(),
        'duration_controller': TextEditingController(text: '2'),
        'assigned_users': <Map<String, dynamic>>[]
      });
    });
  }

  void _removeStep(int index) {
    if (_steps.length <= 1) return;
    setState(() {
      ((_steps[index]['controller']) as TextEditingController).dispose();
      ((_steps[index]['duration_controller']) as TextEditingController).dispose();
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
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(stepIndex != null ? "Assign User to Step ${stepIndex + 1}" : "Select Leader", style: AppTypography.heading2),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextField(
                controller: _userSearchCtrl,
                style: AppTypography.bodyLarge,
                decoration: InputDecoration(
                  hintText: "Search users...", 
                  hintStyle: AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary),
                  prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  filled: true, fillColor: AppColors.surface,
                ),
                onChanged: (v) async {
                  await _searchUsers(v);
                  setModalState(() {});
                },
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isSearching
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _searchResults.length,
                    itemBuilder: (ctx, i) {
                      final user = _searchResults[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=${user['id']}'),
                        ),
                        title: Text(user['full_name'] ?? 'Unknown', style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
                        subtitle: Text(user['email'] ?? '', style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
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
        data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: AppColors.primary)),
        child: child!,
      ),
    );
    if (date != null) setState(() => _deadline = date);
  }

  Future<void> _submitTask() async {
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
        final durCtrl = s['duration_controller'] as TextEditingController;
        final users = s['assigned_users'] as List<Map<String, dynamic>>;
        return {
          'title': ctrl.text.trim(),
          'duration_days': int.tryParse(durCtrl.text.trim()) ?? 2,
          'assigned_users': users.map((u) => u['id']).toList(),
        };
      }).toList();

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

  void _showSnack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.primary));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent, 
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20), onPressed: () => Navigator.pop(context)),
        title: Text("Create Task", style: AppTypography.heading2),
        centerTitle: true,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label("Task Title"),
              _inputField(_titleCtrl, "e.g. Mobile App Launch", Icons.title_rounded),
              const SizedBox(height: 24),
      
              _label("Description"),
              _inputField(_descCtrl, "Describe the task...", Icons.description_rounded, maxLines: 3),
              const SizedBox(height: 24),
      
              _label("Priority"),
              _buildPrioritySelector(),
              const SizedBox(height: 24),
      
              _label("Deadline"),
              GestureDetector(
                onTap: _pickDeadline,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.divider)),
                  child: Row(children: [
                    const Icon(Icons.calendar_today_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Text(_deadline != null ? "${_deadline!.day}/${_deadline!.month}/${_deadline!.year}" : "Select deadline", 
                      style: AppTypography.bodyLarge.copyWith(color: _deadline != null ? AppColors.textPrimary : AppColors.textSecondary)),
                  ]),
                ),
              ),
              const SizedBox(height: 24),
      
              _label("Leader (Optional)"),
              GestureDetector(
                onTap: () => _showUserSearchDialog(),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.divider)),
                  child: Row(children: [
                    const Icon(Icons.star_rounded, color: AppColors.warning, size: 20),
                    const SizedBox(width: 12),
                    Text(_leader != null ? "⭐ ${_leader!['full_name']}" : "Assign a leader", 
                      style: AppTypography.bodyLarge.copyWith(color: _leader != null ? AppColors.textPrimary : AppColors.textSecondary)),
                    const Spacer(),
                    if (_leader != null) GestureDetector(
                      onTap: () => setState(() => _leader = null),
                      child: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 32),
      
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text("Workflow Steps", style: AppTypography.heading2),
                TextButton.icon(
                  onPressed: _addStep, 
                  icon: const Icon(Icons.add_circle_rounded, size: 20, color: AppColors.primary), 
                  label: Text("Add Step", style: AppTypography.bodyMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold))
                ),
              ]),
              const SizedBox(height: 16),
              ..._steps.asMap().entries.map((e) => _buildStepCard(e.key)),
              const SizedBox(height: 40),
      
              SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitTask,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text("Create Task", style: AppTypography.heading3.copyWith(color: Colors.white)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 4),
    child: Text(text, style: AppTypography.heading3),
  );

  Widget _inputField(TextEditingController ctrl, String hint, IconData icon, {int maxLines = 1}) => Container(
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.divider)),
    child: TextField(
      controller: ctrl, maxLines: maxLines,
      style: AppTypography.bodyLarge,
      decoration: InputDecoration(
        hintText: hint, 
        hintStyle: AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary),
        prefixIcon: Icon(icon, color: AppColors.primary, size: 20), 
        border: InputBorder.none, 
        contentPadding: const EdgeInsets.all(16)
      ),
    ),
  );

  Widget _buildPrioritySelector() => Row(
    children: ['low', 'medium', 'high', 'urgent'].map((p) {
      final sel = _priority == p;
      final color = switch (p) { 'urgent' => AppColors.error, 'high' => AppColors.warning, 'low' => AppColors.success, _ => AppColors.info };
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _priority = p),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: sel ? color : AppColors.surface, borderRadius: BorderRadius.circular(16),
              border: Border.all(color: sel ? color : AppColors.divider),
              boxShadow: sel ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))] : [],
            ),
            child: Text(p[0].toUpperCase() + p.substring(1), textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: sel ? Colors.white : AppColors.textSecondary)),
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
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Center(child: Text("${index + 1}", style: AppTypography.heading3.copyWith(color: AppColors.primary))),
          ),
          const SizedBox(width: 12),
          Expanded(child: TextField(
            controller: ctrl, 
            decoration: InputDecoration(
              hintText: "Step title...", 
              hintStyle: AppTypography.heading3.copyWith(color: AppColors.textSecondary),
              border: InputBorder.none, isDense: true
            ), 
            style: AppTypography.heading3
          )),
          if (_steps.length > 1) GestureDetector(onTap: () => _removeStep(index), child: const Icon(Icons.remove_circle_outline, color: AppColors.error, size: 24)),
        ]),
        const SizedBox(height: 16),
        Row(
          children: [
            const Icon(Icons.access_time_rounded, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text("Duration: ", style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
            SizedBox(
              width: 50,
              height: 32,
              child: TextField(
                controller: step['duration_controller'] as TextEditingController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.divider)),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text("days", style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
          ],
        ),
        const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1, color: AppColors.divider)),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ...users.map((u) => Chip(
            avatar: CircleAvatar(backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=${u['id']}'), radius: 12),
            label: Text(u['full_name'] ?? '', style: AppTypography.bodySmall),
            deleteIcon: const Icon(Icons.close, size: 14, color: AppColors.textSecondary),
            onDeleted: () => setState(() => users.removeWhere((x) => x['id'] == u['id'])),
            backgroundColor: AppColors.background,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: AppColors.divider)),
          )),
          ActionChip(
            avatar: const Icon(Icons.person_add_rounded, size: 16, color: AppColors.primary),
            label: Text("Assign", style: AppTypography.bodySmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
            onPressed: () => _showUserSearchDialog(stepIndex: index),
            backgroundColor: AppColors.primary.withValues(alpha: 0.05),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide.none),
          ),
        ]),
      ]),
    );
  }
}
