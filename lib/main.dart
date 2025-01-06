import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/home_page.dart';
import 'pages/settings_page.dart';
import 'pages/chat_page.dart';
import 'pages/create_chat_page.dart';
import 'pages/admin_page.dart';
import 'pages/user_settings_page.dart';
import 'services/theme_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Theme service'i başlat
  final themeService = ThemeService();
  await themeService.init();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _themeService = ThemeService();

  void _handleThemeChange() {
    setState(() {}); // MaterialApp'i yeniden oluştur
  }

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_handleThemeChange);
  }

  @override
  void dispose() {
    _themeService.removeListener(_handleThemeChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _themeService,
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'WhatsChat App',
        themeMode: _themeService.themeMode,
        theme: _themeService.lightTheme,
        darkTheme: _themeService.darkTheme,
        initialRoute:
            FirebaseAuth.instance.currentUser == null ? '/login' : '/home',
        routes: {
          '/login': (context) => const LoginPage(),
          '/register': (context) => const RegisterPage(),
          '/home': (context) => const HomePage(),
          '/admin': (context) => const AdminPage(),
          '/create-chat': (context) => const CreateChatPage(),
          '/settings': (context) => const UserSettingsPage(),
          '/chat': (context) {
            final arguments = ModalRoute.of(context)?.settings.arguments
                as Map<String, dynamic>;
            return ChatPage(
              userName: arguments['userEmail'],
              isGroup: arguments['isGroup'] ?? false,
            );
          },
        },
      ),
    );
  }
}
