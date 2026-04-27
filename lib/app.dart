import 'package:flutter/material.dart';
import 'ui/screens/onboarding_screen.dart';
import 'ui/screens/chat_list_screen.dart';
import 'services/identity_service.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FamilyChat',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF25D366)),
        useMaterial3: true,
      ),
      home: FutureBuilder<bool>(
        future: IdentityService.instance.isOnboarded(),
        builder: (context, snap) {
          if (snap.hasError) return Scaffold(body: Center(child: Text('Ошибка инициализации: ${snap.error}')));
          if (!snap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
          return snap.data! ? const ChatListScreen() : const OnboardingScreen();
        },
      ),
    );
  }
}
