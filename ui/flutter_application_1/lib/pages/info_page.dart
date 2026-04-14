import 'package:flutter/material.dart';
import 'menu_page.dart';


class InfoPage extends StatelessWidget {
  const InfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width < 600 ? double.infinity : 440.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Sleep Tracker by DK'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Card(
              elevation: 12,
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
              color: Colors.deepPurple.shade50,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: Colors.deepPurple[100],
                      child: const Icon(
                        Icons.nightlight_round,
                        color: Colors.deepPurple,
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'App information',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                        letterSpacing: 1.0,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    const Divider(
                      height: 10,
                      thickness: 1.4,
                      color: Colors.deepPurple,
                      endIndent: 80,
                      indent: 80,
                    ),
                    const SizedBox(height: 24),
                    const Text(
  "Welcome to the AI Sleep Tracker!\n\n"
  "This app helps you understand and improve your sleep with two main functions:\n\n"
  "1) AI Sleep Evaluation:\n"
  "- Every day you can enter your sleep data (sleep duration, awakenings, caffeine, screen time, etc.).\n"
  "- The AI analyzes your data and gives you a sleep score with personalized recommendations.\n\n"
  "2) Pittsburgh Sleep Quality Index (PSQI):\n"
  "- This is a scientific questionnaire used worldwide to measure sleep quality.\n"
  "- By answering the questions, you get a detailed report of your overall sleep quality and problem areas.\n\n"
  "Tip: Use the daily AI evaluation for short-term feedback, and the PSQI test for a more complete picture of your sleep quality.\n"
  "Together, they help you track your progress and improve your daily life!"

,
                      style: TextStyle(
                        fontSize: 18,
                        height: 1.6,
                        color: Colors.black87,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.2,
                      ),
                      textAlign: TextAlign.justify,
                    ),
                    const SizedBox(height: 36),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Home', style: TextStyle(fontSize: 18)),
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const MenuPage(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
