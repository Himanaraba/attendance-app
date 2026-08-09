import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'config/app_theme.dart';

import 'providers/auth_provider.dart';
import 'providers/event_provider.dart';
import 'providers/attendance_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/language_provider.dart';
import 'providers/debug_provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/update_screen.dart';
import 'services/update_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // システムナビゲーションバー (下の3ボタン) を常時隠す。
  // ステータスバーは残す。下端からのスワイプで一時表示。
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
    overlays: [SystemUiOverlay.top],
  );
  await initializeDateFormatting('ja_JP', null);
  runApp(const AttendanceApp());
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => DebugProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()..init()),
        ChangeNotifierProvider(create: (_) => EventProvider()),
        ChangeNotifierProvider(create: (_) => AttendanceProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (_, themeProv, __) => MaterialApp(
          title: '出欠管理',
          debugShowCheckedModeBanner: false,
          themeMode: themeProv.mode,
          theme: buildAppTheme(Brightness.light),
          darkTheme: buildAppTheme(Brightness.dark),
          // Android 14 以降のフォントスケールは最大200%かつ非線形。
          // 端末の設定は尊重しつつ、レイアウトが壊れる上限だけ切る。
          builder: (context, child) => MediaQuery.withClampedTextScaling(
            minScaleFactor: 1.0,
            maxScaleFactor: 1.6,
            child: child ?? const SizedBox.shrink(),
          ),
          home: const _AppGate(),
        ),
      ),
    );
  }
}

class _AppGate extends StatefulWidget {
  const _AppGate();
  @override
  State<_AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<_AppGate> {
  UpdateInfo? _updateInfo;
  bool _updateChecked = false;
  bool _updateSkipped = false;

  @override
  void initState() {
    super.initState();
    _checkUpdate();
  }

  Future<void> _checkUpdate() async {
    final info = await UpdateService.check();
    if (!mounted) return;
    setState(() {
      _updateInfo = info;
      _updateChecked = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    // アップデート確認 (起動時のみ・スキップ可能)
    if (_updateChecked && _updateInfo != null && !_updateSkipped) {
      return UpdateScreen(
        info: _updateInfo!,
        onSkipped: _updateInfo!.isForced
            ? null
            : () => setState(() => _updateSkipped = true),
      );
    }

    final auth = context.watch<AuthProvider>();
    if (!auth.initialized || !_updateChecked) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!auth.isLoggedIn) return const LoginScreen();
    if (auth.mustChangePw) {
      // 初回ログインはオンボーディング画面 (パスワード+プロフィール一括登録)
      return const OnboardingScreen();
    }
    return const MainScreen();
  }
}
