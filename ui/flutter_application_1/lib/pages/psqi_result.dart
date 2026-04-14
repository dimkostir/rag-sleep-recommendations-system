import 'package:flutter/material.dart';


class PSQIResultPage extends StatelessWidget {
  const PSQIResultPage({super.key});

  @override
  Widget build(BuildContext context) {
    // arguments from last redirect
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;

    final psqiScore = args?['psqi_score'] ?? "—";
    final badge = args?['badge'] ?? "—";
    final level = args?['level'] ?? "—";
    final suggestions = args?['suggestions'] ?? "—";
    final agentResult = args?['result'] ?? "No analysis found.";

    final isGood = badge == "Sleep Champion";

    return Scaffold(
      appBar: AppBar(
        title: const Text("PSQI Evaluation Result"),
        centerTitle: true,
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
            children: [
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                color: isGood ? Colors.green[50] : Colors.yellow[50],
                elevation: 5,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.hotel, color: isGood ? Colors.green : Colors.orange, size: 32),
                          const SizedBox(width: 12),
                          Text(
                            "PSQI Score: $psqiScore",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: isGood ? Colors.green[900] : Colors.orange[900],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isGood ? Colors.green[200] : Colors.orange[200],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isGood ? Icons.emoji_events : Icons.star_half,
                                  color: isGood ? Colors.green[700] : Colors.orange[700],
                                  size: 22,
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  "Badge: $badge",
                                  style: TextStyle(
                                    color: isGood ? Colors.green[800] : Colors.orange[800],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.blue[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.stars, color: Colors.blue, size: 22),
                                const SizedBox(width: 7),
                                Text("Level $level", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blue[800])),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "Agent's Scientific Feedback:",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: SingleChildScrollView(
                          child: SelectableText(
                            agentResult,
                            style: const TextStyle(fontSize: 15, height: 1.35),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      //Text(
                       // "Personalized Recommendation:",
                       // style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey[700]),
                     // ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: Colors.lightBlue[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          suggestions,
                          style: const TextStyle(fontSize: 15, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 36),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, color: Colors.deepPurple[300], size: 18),
                  const SizedBox(width: 6),
                  Text(
                    "The higher the PSQI score, the lower your sleep quality.",
                    style: TextStyle(color: Colors.deepPurple[300], fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
