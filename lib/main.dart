import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/chat/chat_page.dart';
import 'core/database/database_helper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.instance.database;
  runApp(const ProviderScope(child: MedicalAssistantApp()));
}

class MedicalAssistantApp extends StatelessWidget {
  const MedicalAssistantApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'المساعد الطبي المحلي',
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal, fontFamily: 'sans'),
    locale: const Locale('ar'),
    home: const Directionality(textDirection: TextDirection.rtl, child: ChatPage()),
  );
}
