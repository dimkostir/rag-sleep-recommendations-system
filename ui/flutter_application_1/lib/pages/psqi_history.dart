// File: psqi_history_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/config.dart';

class PSQIHistoryPage extends StatefulWidget {
  const PSQIHistoryPage({super.key});

  @override
  State<PSQIHistoryPage> createState() => _PSQIHistoryPageState();
}

class _PSQIHistoryPageState extends State<PSQIHistoryPage> {
  DateTime _selectedDate = DateTime.now();

  bool _loading = false;
  String? _error;
  bool _hasData = false;
  bool _didReadArgs = false;

  // Data to display
  String psqiScore = "—";
  String badge = "—";
  String level = "—";
  String suggestions = "—";
  String agentResult = "No analysis found.";

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didReadArgs) return;

    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      if (args['date'] is DateTime) {
        _selectedDate = args['date'] as DateTime;
      } else if (args['date'] is String) {
        final parsed = DateTime.tryParse(args['date'] as String);
        if (parsed != null) _selectedDate = parsed;
      }
    }
    _didReadArgs = true;
    _fetchPsqiForDate(_selectedDate);
  }

  String _fmt(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023, 1, 1),
      lastDate: DateTime.now(),
      helpText: 'Select PSQI date',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      await _fetchPsqiForDate(picked);
    }
  }

  Future<void> _fetchPsqiForDate(DateTime date) async {
    setState(() {
      _loading = true;
      _error = null;
      _hasData = false;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      final uri = Uri.parse('${AppConfig.baseUrl}/psqi_history?date=${_fmt(date)}');

      final res = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (res.statusCode == 200) {
        final decoded = utf8.decode(res.bodyBytes);
        final payload = json.decode(decoded) as Map<String, dynamic>?;
        final list = (payload?['history'] as List?) ?? const [];

        if (list.isEmpty) {
          setState(() {
            _hasData = false;
            psqiScore = "—";
            badge = "—";
            level = "—";
            suggestions = "—";
            agentResult = "No PSQI data for ${_fmt(date)}.";
          });
        } else {
          final item = Map<String, dynamic>.from(list.first as Map);

          // Exact keys you store in DB
          final scoreStr = (item['psqi_score'] ?? "—").toString();
          final badgeStr = (item['badge'] ?? "—").toString();
          final levelStr = (item['level'] ?? "—").toString();

          // agent_result (fallback to other common keys just in case)
          final agent = (item['agent_result'] ??
                  item['result'] ??
                  item['analysis'] ??
                  "No analysis found.")
              .toString();

          // suggestions can be String or List
          String sugg = "—";
          final rawSug = item['suggestions'];
          if (rawSug is String && rawSug.trim().isNotEmpty) {
            sugg = rawSug.trim();
          } else if (rawSug is List) {
            final parts = rawSug.whereType<String>().map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
            if (parts.isNotEmpty) {
              sugg = '• ' + parts.join('\n• ');
            }
          }

          setState(() {
            _hasData = true;
            psqiScore = scoreStr;
            badge = badgeStr;
            level = levelStr;
            agentResult = agent;
            suggestions = sugg;
          });
        }
      } else if (res.statusCode == 404) {
        setState(() {
          _hasData = false;
          psqiScore = "—";
          badge = "—";
          level = "—";
          suggestions = "—";
          agentResult = "No PSQI data for ${_fmt(date)}.";
        });
      } else {
        setState(() => _error = 'Server error (${res.statusCode}). Please try again.');
      }
    } catch (e) {
      setState(() => _error = 'Network error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGood = badge == "Sleep Champion";

    return Scaffold(
      appBar: AppBar(
        title: const Text("PSQI History"),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(_fmt(_selectedDate), style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          IconButton(
            tooltip: 'Pick date',
            icon: const Icon(Icons.calendar_today),
            onPressed: _pickDate,
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
            children: [
              if (_loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: CircularProgressIndicator(),
                  ),
                ),
              if (_error != null && !_loading)
                Card(
                  color: Colors.red[50],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red))),
                        TextButton.icon(
                          onPressed: () => _fetchPsqiForDate(_selectedDate),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              if (!_loading)
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
                        const SizedBox(height: 8),
                        Text("Date: ${_fmt(_selectedDate)}", style: TextStyle(color: Colors.grey[700])),
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
                                  Icon(isGood ? Icons.emoji_events : Icons.star_half,
                                      color: isGood ? Colors.green[700] : Colors.orange[700], size: 22),
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
                                  Text("Level $level",
                                      style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blue[800])),
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
                        if (!_hasData) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.deepPurple[300], size: 18),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  "No PSQI data found for the selected date.",
                                  style: TextStyle(color: Colors.deepPurple[300], fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ],
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
