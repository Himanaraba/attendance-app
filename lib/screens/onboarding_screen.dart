import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../providers/auth_provider.dart';
import '../providers/debug_provider.dart';
import '../providers/language_provider.dart';
import '../services/api_service.dart';

// M=中学 / H=高校 / G=グローバル高校 / ID=ID学園 / OB=卒業生。
// サーバー側 app.py の GRADE_OPTIONS と必ず一致させること。
const _gradeOptions = [
  'M1', 'M2', 'M3', 'H1', 'H2', 'H3', 'H4',
  'G1', 'G2', 'G3', 'ID1', 'ID2', 'ID3', 'OB',
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _newPwCtl  = TextEditingController();
  final _confPwCtl = TextEditingController();
  final _discordCtl = TextEditingController();
  String? _grade;
  DateTime? _birthday;
  final Set<String> _positions = {};
  bool _saving = false;
  bool _obscure = true;

  @override
  void dispose() {
    _newPwCtl.dispose();
    _confPwCtl.dispose();
    _discordCtl.dispose();
    super.dispose();
  }

  Future<void> _pickBirthday() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(DateTime.now().year - 16, 1, 1),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (d != null && mounted) setState(() => _birthday = d);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final dio = Dio();
    final token = await SecureStorage.getAccessToken();
    final body = <String, dynamic>{
      'new_password': _newPwCtl.text,
      'grade':        _grade,
      'positions':    _positions.toList(),
      'birthday':     _birthday?.toIso8601String().substring(0, 10),
      'discord_id':   _discordCtl.text.trim(),
    };
    try {
      await dio.post(
        '${ApiConfig.kBaseUrl}/api/v1/auth/onboarding',
        data: body,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      // 完了後 user を再取得して must_change_password=false を反映
      if (!mounted) return;
      await context.read<AuthProvider>().refreshUser();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.read<LanguageProvider>().t('onboarding.complete'))));
    } on DioException catch (e) {
      final serverErr = (e.response?.data as Map?)?['error']?.toString();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(DebugProvider.verbose
              ? '${e.response?.statusCode}: ${serverErr ?? e.message}'
              : (serverErr ?? context.read<LanguageProvider>().t('onboarding.save_failed'))),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    return Scaffold(
      appBar: AppBar(
        title: Text(lang.t('onboarding.title')),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        lang.t('onboarding.welcome'),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── パスワード ──
                  Text(lang.t('onboarding.password_label'),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _newPwCtl,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: lang.t('auth.password_new'),
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: IconButton(
                        tooltip: lang.t('auth.password_toggle'),
                        icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return lang.t('common.required');
                      if (v.length < 8) return lang.t('auth.password_min8');
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _confPwCtl,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: lang.t('onboarding.confirm'),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: (v) => v != _newPwCtl.text ? lang.t('auth.password_mismatch') : null,
                  ),
                  const SizedBox(height: 24),

                  // ── プロフィール (任意) ──
                  Text(lang.t('onboarding.profile'),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    initialValue: _grade,
                    decoration: InputDecoration(
                      labelText: lang.t('onboarding.grade'),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      DropdownMenuItem<String?>(value: null, child: Text(lang.t('onboarding.grade_unset'))),
                      for (final g in _gradeOptions)
                        DropdownMenuItem<String?>(value: g, child: Text(g)),
                    ],
                    onChanged: (v) => setState(() => _grade = v),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _pickBirthday,
                    icon: const Icon(Icons.cake, size: 16),
                    label: Text(_birthday == null
                        ? lang.t('onboarding.birthday')
                        : '${lang.t('onboarding.birthday_selected')} ${_birthday!.toIso8601String().substring(0, 10)}'),
                  ),
                  const SizedBox(height: 12),
                  Text(lang.t('onboarding.positions'), style: const TextStyle(fontSize: 14)),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final (val, key) in [
                        ('tech', 'onboarding.tech'),
                        ('ops', 'onboarding.ops'),
                        ('teacher', 'onboarding.teacher'),
                      ])
                        FilterChip(
                          label: Text(lang.t(key)),
                          selected: _positions.contains(val),
                          onSelected: (on) => setState(() {
                            on ? _positions.add(val) : _positions.remove(val);
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _discordCtl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: lang.t('onboarding.discord'),
                      hintText: lang.t('onboarding.discord_hint'),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return null;
                      return RegExp(r'^\d+$').hasMatch(v) ? null : lang.t('onboarding.digit_only');
                    },
                  ),
                  const SizedBox(height: 6),
                  Text(
                    lang.t('onboarding.discord_help'),
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.check),
                      label: Text(lang.t('onboarding.save')),
                      onPressed: _saving ? null : _submit,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
