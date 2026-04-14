import 'package:flutter/material.dart';
import 'package:flutter_application_1/pages/sleep_entry_page.dart';
import 'pages/first_page.dart';
import 'pages/register_page.dart';
import 'pages/login_page.dart';
import 'pages/about_app_page.dart';
import 'pages/home_page.dart';
import 'pages/menu_page.dart';
import 'pages/evaluation_history.dart';
import 'pages/evaluation_result.dart';
import 'pages/psqi_page.dart';
import 'pages/psqi_result.dart';
import 'pages/info_page.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
//import 'config.dart';


//void main() => runApp(const MyApp());
Future<void> main() async {
  await dotenv.load(fileName: ".env");
  print("🌍 BASE_URL: ${dotenv.env['BASE_URL']}");

  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Sleep Tracker App by DK',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
        cardColor: Colors.deepPurpleAccent.shade100,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.black, width: 2),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.black),
          bodyMedium: TextStyle(color: Colors.black87),
          displayLarge: TextStyle(
            color: Colors.deepPurple,
            fontWeight: FontWeight.bold,
          ),
          headlineSmall: TextStyle(
            color: Colors.deepPurple,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.deepPurple),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
      ),
      home: const FirstPage(),
      debugShowCheckedModeBanner: false,
      routes:{
        '/register': (context) => const RegisterPage(),
        '/login_page': (context) => const LoginPage(),
        '/about': (context) => const AboutAppPage(),
        '/sleep_entry': (context) => const SleepEntryPage(),
        '/menu_page' : (context) => const MenuPage(),
        '/evaluation_history' : (context) => const EvaluationHistoryPage(),
        '/evaluation_result' : (context) => const EvaluationResultPage(),
        '/info' : (context) => const InfoPage(),
        '/psqi_page': (context) =>  PSQIPage(), 
        '/psqi_result': (context) => const PSQIResultPage(),
        '/home_page': (context) => const HomePage()
      }
    );
  }
}
