import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/event_provider.dart';
import '../../providers/language_provider.dart';
import '../../models/event.dart';
import '../../widgets/empty_state.dart';

class EventsAdminScreen extends StatefulWidget {
  const EventsAdminScreen({super.key});

  @override
  State<EventsAdminScreen> createState() => _EventsAdminScreenState();
}

class _EventsAdminScreenState extends State<EventsAdminScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EventProvider>().loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final prov = context.watch<EventProvider>();
    final lang = context.watch<LanguageProvider>();
    return Scaffold(
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 72),
        child: FloatingActionButton(
          onPressed: () => _showForm(context, null),
          child: const Icon(Icons.add),
        ),
      ),
      body: prov.loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => prov.loadAll(),
              child: prov.all.isEmpty
                  ? EmptyState(
                      icon: Icons.event_busy_outlined,
                      title: lang.t('admin.no_activities'),
                      message: lang.t('admin.no_activities_msg'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: prov.all.length,
                      itemBuilder: (_, i) {
                        final ev = prov.all[i];
                        return ListTile(
                          title: Text(ev.title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text(
                              '${ev.date.toString().substring(0, 10)}  '
                              '${ev.startTime}–${ev.endTime}',
                              style: const TextStyle(fontSize: 14)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: lang.t('common.edit'),
                                icon: const Icon(Icons.edit, size: 18),
                                onPressed: () => _showForm(context, ev),
                              ),
                              IconButton(
                                tooltip: lang.t('common.delete'),
                                icon: Icon(Icons.delete, size: 18,
                                    color: Colors.red.shade400),
                                onPressed: () => _delete(context, ev),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  Future<void> _delete(BuildContext context, EventModel ev) async {
    final lang = context.read<LanguageProvider>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang.t('admin.delete_confirm')),
        content: Text('「${ev.title}」${lang.t('admin.delete_ask')}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(lang.t('common.cancel'))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(lang.t('common.delete'), style: TextStyle(color: Colors.red.shade600))),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<EventProvider>().deleteEvent(ev.id);
    }
  }

  Future<void> _showForm(BuildContext context, EventModel? ev) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _EventForm(event: ev),
    );
    if (!context.mounted) return;
    await context.read<EventProvider>().loadAll();
  }
}

class _EventForm extends StatefulWidget {
  final EventModel? event;
  const _EventForm({this.event});

  @override
  State<_EventForm> createState() => _EventFormState();
}

class _EventFormState extends State<_EventForm> {
  final _formKey     = GlobalKey<FormState>();
  final _titleCtl    = TextEditingController();
  final _descCtl     = TextEditingController();
  final _startCtl    = TextEditingController();
  final _endCtl      = TextEditingController();
  DateTime? _date;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final ev = widget.event;
    if (ev != null) {
      _titleCtl.text = ev.title;
      _descCtl.text  = ev.description;
      _startCtl.text = ev.startTime;
      _endCtl.text   = ev.endTime;
      _date          = ev.date;
    }
  }

  @override
  void dispose() {
    _titleCtl.dispose();
    _descCtl.dispose();
    _startCtl.dispose();
    _endCtl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime(TextEditingController ctl, {required bool isStart}) async {
    TimeOfDay? init;
    if (ctl.text.contains(':')) {
      final p = ctl.text.split(':');
      init = TimeOfDay(hour: int.tryParse(p[0]) ?? 15, minute: int.tryParse(p[1]) ?? 0);
    } else {
      init = TimeOfDay(hour: isStart ? 15 : 17, minute: 0);
    }
    final t = await showTimePicker(
      context: context,
      initialTime: init,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (t != null) {
      ctl.text = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
      setState(() {});
    }
  }

  Future<void> _save() async {
    final lang = context.read<LanguageProvider>();
    if (!_formKey.currentState!.validate() || _date == null) {
      if (_date == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(lang.t('admin.select_date_err'))));
      }
      return;
    }
    if (_startCtl.text.isEmpty || _endCtl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lang.t('admin.select_time_err'))));
      return;
    }
    setState(() => _saving = true);
    final data = {
      'title':       _titleCtl.text.trim(),
      'description': _descCtl.text.trim(),
      'date':        _date!.toIso8601String().substring(0, 10),
      'start_time':  _startCtl.text.trim(),
      'end_time':    _endCtl.text.trim(),
    };
    final prov = context.read<EventProvider>();
    bool ok;
    if (widget.event == null) {
      ok = await prov.addEvent(data);
    } else {
      ok = await prov.editEvent(widget.event!.id, data);
    }
    setState(() => _saving = false);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lang.t('admin.save_failed')), backgroundColor: Colors.red));
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
            Text(widget.event == null ? lang.t('admin.event_add') : lang.t('admin.event_edit'),
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
            TextFormField(
              controller: _descCtl,
              decoration: InputDecoration(
                  labelText: lang.t('event.description'), border: const OutlineInputBorder(), isDense: true),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text(_date == null
                  ? lang.t('admin.select_date')
                  : _date!.toIso8601String().substring(0, 10)),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickTime(_startCtl, isStart: true),
                  icon: const Icon(Icons.access_time, size: 16),
                  label: Text(_startCtl.text.isEmpty ? lang.t('event.start_time') : _startCtl.text),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickTime(_endCtl, isStart: false),
                  icon: const Icon(Icons.access_time, size: 16),
                  label: Text(_endCtl.text.isEmpty ? lang.t('event.end_time') : _endCtl.text),
                ),
              ),
            ]),
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
    );
  }
}
