import 'package:flutter/material.dart';

import 'home_page.dart';
import 'notification_service.dart';
import 'storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  final storage = await Storage.load();
  runApp(ElingSholatApp(storage: storage));
}

class ElingSholatApp extends StatelessWidget {
  final Storage storage;
  const ElingSholatApp({super.key, required this.storage});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF1B7F5A);
    return MaterialApp(
      title: 'Eling Sholat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: seed, useMaterial3: true),
      darkTheme: ThemeData(colorSchemeSeed: seed, brightness: Brightness.dark, useMaterial3: true),
      home: HomePage(storage: storage),
    );
  }
}
