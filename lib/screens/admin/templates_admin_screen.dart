import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../services/api_service.dart';

const _dayKeys = ['day.mon', 'day.tue', 'day.wed', 'day.thu', 'day.fri', 'day.sat', 'day.sun'];
const _dayFullKeys = ['day.monday', 'day.tuesday', 'day.wednesday', 'day.thursday', 'day.friday', 'day.saturday', 'day.sunday'];

class TemplatesAdminScreen extends StatefulWidget {
  const TemplatesAdminScreen({super.key});

  @override
  State<TemplatesAdminScreen> createState() => _TemplatesAdminScreenState();
}

class _TemplatesAdminScreenState extends State<TemplatesAdminScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<Map<String, dynamic>> _templates = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.getTemplates();
      setState(() => _templates = data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final lang = context.watch<LanguageProvider>();
    return Scaffold(
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 72),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton.small(
              heroTag: 'generate',
              tooltip: lang.t('admin.generate_tooltip'),
              onPressed: () => _showGenerateDialog(context),
              child: const Icon(Icons.auto_awesome),
            ),
            const SizedBox(height: 8),
            FloatingActionButton(
              heroTag: 'add',
              onPressed: () => _showForm(context, null),
              child: const Icon(Icons.add),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _templates.isEmpty
                  ? Center(child: Text(lang.t('admin.no_templates')))
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: _templates.length,
                      itemBuilder: (_, i) {
                        final t = _templates[i];
                        final dow = t['day_of_week'] as int;
                        final isAuto = t['is_auto'] as bool? ?? false;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _dayColor(dow),
                            radius: 18,
                            child: Text(lang.t(_dayKeys[dow]),
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 14)),
                          ),
                          title: Text(t['title'] ?? '',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text(
                              '${t['start_time']}–${t['end_time']}',
                              style: const TextStyle(fontSize: 14)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isAuto)
                                Tooltip(
                                  message: lang.t('admin.auto_generate'),
                                  child: const Icon(Icons.autorenew,
                                      size: 16, color: Colors.green),
                                ),
                              IconButton(
                                tooltip: lang.t('common.edit'),
                                icon: const Icon(Icons.edit, size: 18),
                                onPressed: () => _showForm(context, t),
                              ),
                              IconButton(
                                tooltip: lang.t('common.delete'),
                                icon: Icon(Icons.delete,
                                    size: 18, color: Colors.red.shade400),
                                onPressed: () => _delete(context, t),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  Color _dayColor(int dow) {
    const colors = [
      Colors.blue, Colors.indigo, Colors.teal,
      Colors.green, Colors.orange, Colors.pink, Colors.red,
    ];
    return colors[dow % colors.length];
  }

  Future<void> _delete(BuildContext context, Map<String, dynamic> t) async {
    final lang = context.read<LanguageProvider>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang.t('admin.delete_confirm')),
        content: Text('「${t['title']}」${lang.t('admin.delete_ask')}'),
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
        await ApiService.deleteTemplate(t['id'] as int);
        await _load();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(e.toString()), backgroundColor: Colors.red));
        }
      }
    }
  }

  void _showForm(BuildContext context, Map<String, dynamic>? t) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _TemplateForm(template: t),
    ).then((_) => _load());
  }

  void _showGenerateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _GenerateDialog(),
    );
  }
}

class _GenerateDialog extends StatefulWidget {
  @override
  State<_GenerateDialog> createState() => _GenerateDialogState();
}

class _GenerateDialogState extends State<_GenerateDialog> {
  DateTime _start = DateTime.now();
  int _weeks = 4;
  bool _loading = false;

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (d != null) setState(() => _start = d);
  }

  Future<void> _generate() async {
    setState(() => _loading = true);
    final lang = context.read<LanguageProvider>();
    try {
      final count = await ApiService.generateEvents(
          _start.toIso8601String().substring(0, 10), _weeks);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$count ${lang.t('admin.generated_n')}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString()), backgroundColor: Colors.red));
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    return AlertDialog(
      title: Text(lang.t('admin.generate_events')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today, size: 16),
            label: Text(_start.toIso8601String().substring(0, 10)),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Text(lang.t('admin.weeks_label')),
            const SizedBox(width: 12),
            Expanded(
              child: Slider(
                value: _weeks.toDouble(),
                min: 1, max: 12, divisions: 11,
                label: '$_weeks ${lang.t('admin.weeks')}',
                onChanged: (v) => setState(() => _weeks = v.round()),
              ),
            ),
            Text('$_weeks ${lang.t('admin.weeks')}'),
          ]),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(lang.t('common.cancel'))),
        FilledButton(
          onPressed: _loading ? null : _generate,
          child: _loading
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(lang.t('admin.generate')),
        ),
      ],
    );
  }
}

class _TemplateForm extends StatefulWidget {
  final Map<String, dynamic>? template;
  const _TemplateForm({this.template});

  @override
  State<_TemplateForm> createState() => _TemplateFormState();
}

class _TemplateFormState extends State<_TemplateForm> {
  final _formKey  = GlobalKey<FormState>();
  final _titleCtl = TextEditingController();
  final _startCtl = TextEditingController();
  final _endCtl   = TextEditingController();
  int _dow    = 0;
  bool _isAuto = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final t = widget.template;
    if (t != null) {
      _titleCtl.text = t['title'] ?? '';
      _startCtl.text = t['start_time'] ?? '';
      _endCtl.text   = t['end_time'] ?? '';
      _dow    = t['day_of_week'] as int? ?? 0;
      _isAuto = t['is_auto'] as bool? ?? false;
    }
  }

  @override
  void dispose() {
    _titleCtl.dispose();
    _startCtl.dispose();
    _endCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final data = {
      'title':       _titleCtl.text.trim(),
      'day_of_week': _dow,
      'start_time':  _startCtl.text.trim(),
      'end_time':    _endCtl.text.trim(),
      'is_auto':     _isAuto,
    };
    try {
      if (widget.template == null) {
        await ApiService.createTemplate(data);
      } else {
        await ApiService.updateTemplate(widget.template!['id'] as int, data);
      }
      setState(() => _saving = false);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString()), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.template == null ? lang.t('admin.template_add') : lang.t('admin.template_edit'),
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _titleCtl,
              decoration: InputDecoration(
                  labelText: lang.t('event.title'), border: const OutlineInputBorder(), isDense: true),
              validator: (v) =>
                  (v == null || v.isEmpty) ? lang.t('common.required') : null,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: _dow,
              isDense: true,
              decoration: InputDecoration(
                  labelText: lang.t('admin.day_of_week'), border: const OutlineInputBorder(), isDense: true),
              items: List.generate(
                  7,
                  (i) => DropdownMenuItem(
                      value: i, child: Text(lang.t(_dayFullKeys[i])))),
              onChanged: (v) => setState(() => _dow = v!),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _startCtl,
                  decoration: InputDecoration(
                      labelText: lang.t('admin.start'), hintText: '15:00',
                      border: const OutlineInputBorder(), isDense: true),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? lang.t('common.required') : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _endCtl,
                  decoration: InputDecoration(
                      labelText: lang.t('admin.end'), hintText: '17:00',
                      border: const OutlineInputBorder(), isDense: true),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? lang.t('common.required') : null,
                ),
              ),
            ]),
            const SizedBox(height: 8),
            SwitchListTile(
              value: _isAuto,
              onChanged: (v) => setState(() => _isAuto = v),
              title: Text(lang.t('admin.auto_generate'), style: const TextStyle(fontSize: 14)),
              subtitle: Text(lang.t('admin.auto_generate_msg'),
                  style: const TextStyle(fontSize: 14)),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),
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
    );
  }
}
