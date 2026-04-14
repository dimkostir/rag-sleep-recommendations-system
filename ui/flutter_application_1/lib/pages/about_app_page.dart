import 'package:flutter/material.dart';
import 'home_page.dart';


class AboutAppPage extends StatelessWidget {
  const AboutAppPage({super.key});

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
                      'About this project',
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
                      "Welcome to the AI Sleep Tracker! This application helps you improve your daily life by analyzing your sleep data and giving you personalized, AI-powered recommendations and feedback.\n\n"
                      "With a simple and secure interface, you can track your sleep, spot patterns, and get tips on how to rest better every night. Your privacy and data security are fully respected.\n\n"
                      "This app also offers the Pittsburgh Sleep Quality Index (PSQI) test. The Pittsburgh Sleep Quality Index (PSQI) is a widely used self-report questionnaire that assesses sleep quality over a one-month time interval.\n "
                      "The measure was developed by Dr. Daniel Buysse, Dr. Charles Reynolds, Dr. Timothy Monk, Dr. Susan Berman, and Dr. David Kupfer at the University of Pittsburgh. Since the PSQI’s publication in 1989, it has been cited in over 34,000 peer-reviewed articles.\n\n"
                      "This project is the result of my final year thesis at the Department of Digital Systems, University of Piraeus, supervised by Professor Andreas Menychtas.\n\n"
                      "I would like to thank Professor Menychtas for his continuous support and guidance throughout this journey.\n\n"
                      "Dimitrios Kostiris E20082",
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
                              builder: (context) => const HomePage(),
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
