import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/empty_state.dart';

class UsersAdminScreen extends StatefulWidget {
  const UsersAdminScreen({super.key});

  @override
  State<UsersAdminScreen> createState() => _UsersAdminScreenState();
}

class _UsersAdminScreenState extends State<UsersAdminScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<Map<String, dynamic>> _users = [];
  bool _loading = false;
  String _query = '';
  String _filterPos = '';
  String _filterRole = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.getUsers();
      setState(() => _users = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _query.trim().toLowerCase();
    return _users.where((u) {
      if (q.isNotEmpty) {
        final name  = (u['name']  as String? ?? '').toLowerCase();
        final email = (u['email'] as String? ?? '').toLowerCase();
        if (!name.contains(q) && !email.contains(q)) return false;
      }
      if (_filterPos.isNotEmpty) {
        final positions = List<String>.from(u['positions'] ?? []);
        if (!positions.contains(_filterPos)) return false;
      }
      if (_filterRole.isNotEmpty) {
        if ((u['role'] ?? '') != _filterRole) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final lang = context.watch<LanguageProvider>();
    final filtered = _filtered;
    return Scaffold(
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 72),
        child: FloatingActionButton(
          onPressed: () => _showForm(context, null),
          child: const Icon(Icons.person_add),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: lang.t('admin.search_hint'),
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: lang.t('common.clear_search'),
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _query = '')),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _chip(lang.t('admin.all_positions'), '', isPos: true),
                _chip(lang.t('admin.tech'), 'tech', isPos: true),
                _chip(lang.t('admin.ops'), 'ops', isPos: true),
                _chip(lang.t('admin.advisor'), 'teacher', isPos: true),
                const SizedBox(width: 12),
                _chip(lang.t('admin.all_roles'), '', isPos: false),
                _chip(lang.t('admin.role_user'), 'user', isPos: false),
                _chip(lang.t('admin.role_manager'), 'manager', isPos: false),
                _chip(lang.t('admin.role_admin'), 'admin', isPos: false),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text('${filtered.length} ${lang.t('admin.n_results')}',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: filtered.isEmpty
                        ? EmptyState(
                            icon: Icons.search_off,
                            title: lang.t('admin.no_matching_users'),
                            message: lang.t('admin.no_matching_msg'),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 80),
                            itemCount: filtered.length,
                            itemBuilder: (_, i) {
                              final u = filtered[i];
                        final role = u['role'] ?? 'user';
                        final positions = List<String>.from(u['positions'] ?? []);
                        final posLabel = positions.map((p) => switch (p) {
                          'tech'    => lang.t('admin.tech_team'),
                          'ops'     => lang.t('admin.ops_team'),
                          'teacher' => lang.t('admin.teacher'),
                          _ => p,
                        }).join(', ');

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _roleColor(role),
                            radius: 18,
                            child: Text(
                              (u['name'] as String?)?.isNotEmpty == true
                                  ? (u['name'] as String)[0]
                                  : '?',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 14),
                            ),
                          ),
                          title: Text(u['name'] ?? '',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text(
                              '${u['email'] ?? ''}  ${posLabel.isNotEmpty ? "[$posLabel]" : ""}',
                              style: const TextStyle(fontSize: 14)),
                          trailing: PopupMenuButton<String>(
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                  value: 'edit',
                                  child: ListTile(
                                      leading: const Icon(Icons.edit),
                                      title: Text(lang.t('common.edit')),
                                      dense: true)),
                              PopupMenuItem(
                                  value: 'reset',
                                  child: ListTile(
                                      leading: const Icon(Icons.lock_reset),
                                      title: Text(lang.t('admin.reset_pw')),
                                      dense: true)),
                              PopupMenuItem(
                                  value: 'delete',
                                  child: ListTile(
                                      leading: const Icon(Icons.delete,
                                          color: Colors.red),
                                      title: Text(lang.t('common.delete'),
                                          style: const TextStyle(color: Colors.red)),
                                      dense: true)),
                            ],
                            onSelected: (action) async {
                              switch (action) {
                                case 'edit':
                                  _showForm(context, u);
                                case 'reset':
                                  await _resetPassword(context, u);
                                case 'delete':
                                  await _deleteUser(context, u);
                              }
                            },
                          ),
                        );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String value, {required bool isPos}) {
    final selected = isPos ? _filterPos == value : _filterRole == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 14)),
        selected: selected,
        onSelected: (_) => setState(() {
          if (isPos) {
            _filterPos = value;
          } else {
            _filterRole = value;
          }
        }),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Color _roleColor(String role) {
    return switch (role) {
      'admin'   => Colors.red.shade600,
      'manager' => Colors.orange.shade700,
      _         => Colors.blue.shade600,
    };
  }

  Future<void> _resetPassword(
      BuildContext context, Map<String, dynamic> u) async {
    final lang = context.read<LanguageProvider>();
    final ctrl = TextEditingController();
    final newPass = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${u['name']} ${lang.t('admin.reset_pw_title')}'),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(
              labelText: lang.t('auth.password_new'), border: const OutlineInputBorder()),
          obscureText: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(lang.t('common.cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: Text(lang.t('admin.set'))),
        ],
      ),
    );
    if (newPass != null && newPass.isNotEmpty && context.mounted) {
      try {
        await ApiService.resetUserPassword(u['id'] as int, newPass);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(lang.t('admin.reset_pw_done'))));
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _deleteUser(
      BuildContext context, Map<String, dynamic> u) async {
    final lang = context.read<LanguageProvider>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang.t('admin.user_delete')),
        content: Text('「${u['name']}」${lang.t('admin.delete_ask')}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(lang.t('common.cancel'))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(lang.t('common.delete'),
                  style: TextStyle(color: Colors.red.shade600))),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      try {
        await ApiService.deleteUser(u['id'] as int);
        await _load();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(e.toString()), backgroundColor: Colors.red));
        }
      }
    }
  }

  void _showForm(BuildContext context, Map<String, dynamic>? u) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _UserForm(user: u),
    ).then((_) => _load());
  }
}

class _UserForm extends StatefulWidget {
  final Map<String, dynamic>? user;
  const _UserForm({this.user});

  @override
  State<_UserForm> createState() => _UserFormState();
}

class _UserFormState extends State<_UserForm> {
  final _formKey   = GlobalKey<FormState>();
  final _nameCtl   = TextEditingController();
  final _emailCtl  = TextEditingController();
  String _role     = 'user';
  String? _grade;
  String _class    = '';

  // M=中学 / H=高校 / G=グローバル高校 / ID=ID学園 / OB=卒業生。
  // サーバー側 app.py の GRADE_OPTIONS と必ず一致させること。
  static const _gradeOptions = [
    'M1', 'M2', 'M3', 'H1', 'H2', 'H3', 'H4',
    'G1', 'G2', 'G3', 'ID1', 'ID2', 'ID3', 'OB',
  ];
  final Set<String> _positions = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    if (u != null) {
      _nameCtl.text  = u['name'] ?? '';
      _emailCtl.text = u['email'] ?? '';
      _role          = u['role'] ?? 'user';
      final gRaw = u['grade']?.toString();
      _grade         = (gRaw != null && _gradeOptions.contains(gRaw)) ? gRaw : null;
      _class         = u['user_class'] ?? '';
      _positions.addAll(List<String>.from(u['positions'] ?? []));
    }
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _emailCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final data = <String, dynamic>{
      'name':       _nameCtl.text.trim(),
      'email':      _emailCtl.text.trim(),
      'role':       _role,
      'grade':      _grade,
      'user_class': _class,
      'positions':  _positions.toList(),
    };
    try {
      if (widget.user == null) {
        final tempPw = await ApiService.createUser(data);
        setState(() => _saving = false);
        if (!mounted) return;
        Navigator.pop(context);
        if (tempPw != null) {
          await _showTempPasswordDialog(context, _nameCtl.text.trim(), tempPw);
        }
      } else {
        await ApiService.updateUser(widget.user!['id'] as int, data);
        setState(() => _saving = false);
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _showTempPasswordDialog(BuildContext ctx, String name, String pw) {
    final lang = ctx.read<LanguageProvider>();
    return showDialog<void>(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(lang.t('admin.temp_pw_issued')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$name ${lang.t('admin.temp_pw_share')}'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                pw,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              lang.t('admin.temp_pw_note'),
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy),
            label: Text(lang.t('admin.copy')),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: pw));
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(content: Text(lang.t('admin.copied')),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 1)),
              );
            },
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.user == null ? lang.t('admin.user_add') : lang.t('admin.user_edit'),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameCtl,
                decoration: InputDecoration(
                    labelText: lang.t('admin.name'), border: const OutlineInputBorder(), isDense: true),
                validator: (v) =>
                    (v == null || v.isEmpty) ? lang.t('common.required') : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailCtl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                    labelText: lang.t('admin.email_label'), border: const OutlineInputBorder(), isDense: true),
                validator: (v) =>
                    (v == null || v.isEmpty) ? lang.t('common.required') : null,
              ),
              const SizedBox(height: 8),
              if (widget.user == null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    const Icon(Icons.info_outline, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      lang.t('admin.temp_pw_info'),
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                    )),
                  ]),
                ),
                const SizedBox(height: 8),
              ],
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _role,
                    isDense: true,
                    decoration: InputDecoration(
                        labelText: lang.t('admin.role'), border: const OutlineInputBorder(), isDense: true),
                    items: [
                      DropdownMenuItem(value: 'user',    child: Text(lang.t('admin.role_user'))),
                      DropdownMenuItem(value: 'manager', child: Text(lang.t('admin.role_manager'))),
                      DropdownMenuItem(value: 'admin',   child: Text(lang.t('admin.role_admin'))),
                    ],
                    onChanged: (v) => setState(() => _role = v!),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: _grade,
                    isDense: true,
                    decoration: InputDecoration(
                        labelText: lang.t('admin.grade_optional'), border: const OutlineInputBorder(), isDense: true),
                    items: [
                      DropdownMenuItem<String?>(value: null, child: Text(lang.t('onboarding.grade_unset'))),
                      for (final g in _gradeOptions)
                        DropdownMenuItem<String?>(value: g, child: Text(g)),
                    ],
                    onChanged: (v) => setState(() => _grade = v),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Text(lang.t('admin.positions'), style: const TextStyle(fontSize: 14)),
              Wrap(
                spacing: 8,
                children: [
                  for (final (val, key) in [
                    ('tech', 'admin.tech_team'),
                    ('ops', 'admin.ops_team'),
                    ('teacher', 'admin.teacher'),
                  ])
                    FilterChip(
                      label: Text(lang.t(key), style: const TextStyle(fontSize: 14)),
                      selected: _positions.contains(val),
                      onSelected: (on) => setState(() {
                        on ? _positions.add(val) : _positions.remove(val);
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(lang.t('common.save')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
