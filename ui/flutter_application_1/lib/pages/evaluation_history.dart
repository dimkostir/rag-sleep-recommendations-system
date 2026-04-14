import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter_application_1/config.dart';

class EvaluationHistoryPage extends StatefulWidget {
  const EvaluationHistoryPage({super.key});

  @override
  State<EvaluationHistoryPage> createState() => _EvaluationHistoryPageState();
}

class _EvaluationHistoryPageState extends State<EvaluationHistoryPage> {
  String? result;
  int? sleepScore;
  String? badge;
  int? streak;
  int? personalBest;
  int? averageScore;
  int? level;

  // New fields to mirror EvaluationResultPage
  int? stress;
  String? stressLabel;
  String? bedTimeLabel;
  String? category;

  bool loading = false;
  String? error;
  DateTime selectedDate = DateTime.now();

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  @override
  void initState() {
    super.initState();
    fetchHistory(selectedDate);
  }

  Future<void> fetchHistory(DateTime date) async {
    setState(() {
      loading = true;
      error = null;
      result = null;
      sleepScore = null;
      badge = null;
      streak = null;
      personalBest = null;
      averageScore = null;
      level = null;
      stress = null;
      stressLabel = null;
      bedTimeLabel = null;
      category = null;
    });

    try {
      final token = await _getToken();

      // Build URL pointing to backend
      final url = Uri.parse(AppConfig.baseUrl).replace(
        path: '/history',
        queryParameters: {
          'date': date.toIso8601String().substring(0, 10),
        },
      );

      final headers = <String, String>{
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        if (AppConfig.baseUrl.contains('ngrok'))
          'ngrok-skip-browser-warning': 'true',
      };

      // Debug
      // ignore: avoid_print
      print('GET $url');
      final res = await http.get(url, headers: headers);
      final ct = res.headers['content-type'] ?? '';
      // ignore: avoid_print
      print('status=${res.statusCode}, ct=$ct');

      if (res.statusCode != 200) {
        final snippet = res.body.length > 240 ? res.body.substring(0, 240) : res.body;
        setState(() => error = 'API ${res.statusCode} ($ct): $snippet');
      } else if (!ct.contains('application/json')) {
        final snippet = res.body.length > 240 ? res.body.substring(0, 240) : res.body;
        setState(() => error = 'Non-JSON response ($ct): $snippet');
      } else {
        final data = jsonDecode(res.body);
        final historyList = (data['history'] as List?) ?? const [];
        if (historyList.isNotEmpty) {
          final entry = historyList.first as Map<String, dynamic>;

          // Be robust to key naming differences (agent_result vs result, etc.)
          setState(() {
            result       = (entry['agent_result'] ?? entry['result']) as String?;
            sleepScore   = entry['sleep_score'] as int?;
            badge        = entry['badge'] as String?;
            streak       = entry['streak'] as int?;
            personalBest = entry['personal_best'] as int?;
            averageScore = entry['average_score'] as int?;
            level        = entry['level'] as int?;

            // New optional fields (may not exist in older history entries)
            stress       = entry['stress_level'] as int?;
            stressLabel  = entry['stress_label'] as String?;
            bedTimeLabel = entry['bedtime_label'] as String?;
            category     = entry['category'] as String?;
          });
        } else {
          setState(() => error = 'No data found for this date.');
        }
      }
    } catch (e) {
      setState(() => error = 'Request failed: $e');
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _pickDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2023, 1, 1),
      lastDate: DateTime.now(),
      helpText: 'Select date for history',
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
      await fetchHistory(picked);
    }
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
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isWide = screenWidth > 700;
    final double maxWidth = isWide ? 800 : 430;

    // Match card structure/order of EvaluationResultPage
    final List<List<Widget>> cardPairs = [
      [
        _buildCard(
          title: "Sleep Score",
          icon: Icons.score,
          content: sleepScore != null ? "$sleepScore / 100" : "-",
          bar: sleepScore != null ? _buildScoreBar(sleepScore!) : null,
        ),
        _buildCard(
          title: "Badge",
          icon: Icons.emoji_events,
          content: badge ?? "-",
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
          content: (bedTimeLabel != null) ? "$bedTimeLabel" : "-",
        ),
      ],
      [
        _buildCard(
          title: "Streak",
          icon: Icons.local_fire_department,
          content: streak != null && streak! > 0 ? "$streak days in a row!" : "-",
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
        title: const Text('Sleep History'),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: 'Pick date',
            onPressed: () => _pickDate(context),
          ),
        ],
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
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.history, color: Colors.deepPurple, size: 54),
                          const SizedBox(height: 16),
                          const Text(
                            'Sleep Report History',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Date: ${_formatDate(selectedDate)}',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.deepPurple.shade700,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 24),

                          if (error != null)
                            Card(
                              color: Colors.red.shade50,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error, color: Colors.red, size: 30),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        error!,
                                        style: const TextStyle(fontSize: 18, color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else ...[
                            // Category chip (same as EvaluationResultPage)
                            if (category != null && category!.trim().isNotEmpty)
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
                                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                  elevation: 8,
                                ),
                              ),

                            const SizedBox(height: 16),

                            // Responsive pairs (same layout behavior)
                            ...cardPairs.map(
                              (pair) => Padding(
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
                              ),
                            ),

                            // Agent feedback (result)
                            if (result != null && result!.isNotEmpty)
                              Card(
                                color: Color.fromARGB(255, 230, 203, 240),
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
                          ],

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

  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}";
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
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 17,
                    ),
                  ),
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
