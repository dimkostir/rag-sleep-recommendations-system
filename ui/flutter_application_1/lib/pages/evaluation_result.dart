import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter_application_1/config.dart';

class EvaluationResultPage extends StatefulWidget {
  const EvaluationResultPage({super.key});

  @override
  State<EvaluationResultPage> createState() => _EvaluationResultPageState();
}

class _EvaluationResultPageState extends State<EvaluationResultPage> {
  String? result;
  int? sleepScore;
  String? badge;
  int? streak;
  int? personalBest;
  int? stress;
  String? stressLabel;               
  String? sleep;          
  String? bedTimeLabel;             
  int? averageScore;
  int? level;
  String? category;
  bool loading = true;
  String? error;

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  @override
  void initState() {
    super.initState();
    fetchEvaluation();
  }

  Future<void> fetchEvaluation() async {
    setState(() {
      loading = true;
      error = null;
      result = null;
    });
    try {
      final token = await _getToken();
      final url = Uri.parse('${AppConfig.baseUrl}/agent/evaluate');
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          result = data['result'];
          sleepScore = data['sleep_score'];
          stress = data['stress_level'];
          stressLabel = data['stress_label'];                 
          bedTimeLabel = data['bedtime_label'];           
          badge = data['badge'];
          category = data['category'];
          streak = data['streak'];
          personalBest = data['personal_best'];
          averageScore = data['average_score'];
          level = data['level'];
        });
      } else {
        setState(() {
          error = jsonDecode(response.body)['detail']?.toString() ?? 'Error ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        error = e.toString();
      });
    }
    setState(() {
      loading = false;
    });
  }

  Color _categoryColor(String text) {
  final t = text.toLowerCase();
  if (text.contains('🟢') || t.contains('perfect')) return Colors.green;
  if (text.contains('🟡') || t.contains('good')) return Colors.amber[700]!;
  if (text.contains('🟠') || t.contains('average')) return Colors.orange[700]!;
  if (text.contains('🔴') || t.contains('bad')) return Colors.red[700]!;
  return Colors.deepPurple;
}





  @override
  Widget build(BuildContext context) {
    // responsive screen, depends on the resolution
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isWide = screenWidth > 700;
    final double maxWidth = isWide ? 800 : 430;

   
    // card pairs
    final List<List<Widget>> cardPairs = [
      [
        _buildCard(
          title: "Sleep Score",
          icon: Icons.score,
          content: sleepScore != null ? "$sleepScore / 100" : "No data",
          bar: sleepScore != null ? _buildScoreBar(sleepScore!) : null,
        ),
        _buildCard(
          title: "Badge",
          icon: Icons.emoji_events,
          content: badge ?? "No badge yet",
          badgeStr: badge,
        ),
      ],
      [
        
        _buildCard(
          title: "Stress Index",
          icon: Icons.tag_faces,
          content: (stressLabel != null && stress != null)
              ? "$stressLabel ($stress/10)"
              : (stress != null ? "$stress/10" : "-"),
        ),
        
        _buildCard(
          title: "Bed time review",
          icon: Icons.thumb_up,
          content: (bedTimeLabel!= null )
              ? "$bedTimeLabel"
              : (bedTimeLabel ?? "-"),
        ),
      ],
      [
        _buildCard(
          title: "Streak",
          icon: Icons.local_fire_department,
          content: streak != null && streak! > 0 ? "$streak days in a row!" : "No streak yet",
        ),
        _buildCard(
          title: "Personal Best",
          icon: Icons.emoji_events_outlined,
          content: personalBest != null ? "$personalBest / 100" : "-",
        ),
      ],
      [
        _buildCard(
          title: "Average (all days)",
          icon: Icons.timeline,
          content: averageScore != null ? "$averageScore / 100" : "-",
        ),
        _buildCard(
          title: "Level",
          icon: Icons.stars_rounded,
          content: level != null ? "Level $level" : "-",
        ),
      ],
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sleep Evaluation'),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Card(
              elevation: 14,
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              color: Colors.deepPurple.shade50,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : error != null
                        ? Text(
                            error!,
                            style: const TextStyle(color: Colors.red, fontSize: 18),
                            textAlign: TextAlign.center,
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.insights, color: Colors.deepPurple, size: 54),
                              const SizedBox(height: 16),
                              const Text(
                                'Your Sleep Report',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepPurple,
                                ),
                              ),
                              const SizedBox(height: 24),
                                  

    if (category !=null && category!.trim().isNotEmpty)...[
      Center(
        child: Chip(
          label: Text(
            category!,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          backgroundColor: _categoryColor(category!),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),elevation: 8,
      ),
    ),
  ],
                                  // Responsive pairs
                              ...cardPairs.map((pair) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    child: isWide
                                        ? Row(
                                            children: [
                                              Expanded(child: pair[0]),
                                              const SizedBox(width: 18),
                                              Expanded(child: pair[1]),
                                            ],
                                          )
                                        : Column(
                                            children: [
                                              pair[0],
                                              const SizedBox(height: 8),
                                              pair[1],
                                            ],
                                          ),
                                  )),

                              // agent feedback card
                              if (result != null && result!.isNotEmpty)
                                Card(
                                  color: const Color.fromARGB(255, 230, 203, 240),
                                  margin: const EdgeInsets.only(top: 22, bottom: 10),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.lightbulb, color: Colors.amber, size: 32),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                "Personalized Suggestions",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 17,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                result!,
                                                style: const TextStyle(fontSize: 16),
                                                textAlign: TextAlign.justify,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                              const SizedBox(height: 32),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.home),
                                  label: const Text('Main Menu'),
                                  onPressed: () {
                                    Navigator.pushReplacementNamed(context, '/menu_page');
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.deepPurple,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                  ),
                                ),
                              )
                            ],
                          ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScoreBar(int score) {
    Color barColor;
    if (score >= 90) {
      barColor = Colors.green;
    } else if (score >= 80) {
      barColor = Colors.teal;
    } else if (score >= 60) {
      barColor = Colors.orange;
    } else {
      barColor = Colors.redAccent;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 6),
      child: LinearProgressIndicator(
        value: score / 100,
        minHeight: 12,
        backgroundColor: Colors.deepPurple.shade100,
        valueColor: AlwaysStoppedAnimation<Color>(barColor),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required String content,
    Widget? bar,
    String? badgeStr,
  }) {
    Color? badgeColor;
    if (badgeStr != null) {
      switch (badgeStr) {
        case "Sleep Master":
          badgeColor = Colors.green;
          break;
        case "Early Bird":
          badgeColor = Colors.orange;
          break;
        case "Night Owl":
          badgeColor = Colors.indigo;
          break;
        case "Sleep Rookie":
          badgeColor = Colors.deepPurple;
          break;
        default:
          badgeColor = Colors.amber;
      }
    }
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
        child: Row(
          children: [
            Icon(icon, size: 36, color: badgeColor ?? Colors.deepPurple),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 17,
                      )),
                  if (bar != null) bar,
                  Text(
                    content,
                    style: TextStyle(
                      fontSize: 19,
                      color: badgeColor ?? Colors.deepPurple.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
