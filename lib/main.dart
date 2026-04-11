import 'package:flutter/material.dart';
import 'screens/chat_screen.dart';
import 'theme.dart';

const String _wsBaseUrl = String.fromEnvironment(
  'WS_BASE_URL',
  defaultValue: 'wss://api.lifetravel.ai',
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LifeTravelApp());
}

class LifeTravelApp extends StatelessWidget {
  const LifeTravelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LifeTravel',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const ChatScreen(wsBaseUrl: _wsBaseUrl),
    );
  }
}
