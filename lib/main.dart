import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:surveillanceuser/Screens/homePage.dart';
import 'package:surveillanceuser/Screens/loginPage.dart';
import 'package:workmanager/workmanager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'User app',
      initialRoute: '/home',
      routes: {
        '/': (context) => loginPage(),
        '/home': (context) => homePage(),
      },
    );
  }
}
