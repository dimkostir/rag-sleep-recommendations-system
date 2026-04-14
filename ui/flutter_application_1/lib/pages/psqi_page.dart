import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PSQIPage extends StatefulWidget {
  const PSQIPage({super.key});

  @override
  State<PSQIPage> createState() => _PSQIPageState();
}

class _PSQIPageState extends State<PSQIPage> {
  final _formKey = GlobalKey<FormState>();

  // Q2 & Q4
  final TextEditingController q2Controller = TextEditingController();
  final TextEditingController q4Controller = TextEditingController();

  // Q1 & Q3
  TimeOfDay? sleepTime;
  TimeOfDay? wakeTime;

  // Q5a–j, Q6–Q9
  final Map<String, int?> dropdownAnswers = {
    "q5a": null, "q5b": null, "q5c": null, "q5d": null, "q5e": null,
    "q5f": null, "q5g": null, "q5h": null, "q5i": null, "q5j": null,
    "q6": null, "q7": null, "q8": null, "q9": null,
    // Q10a–Q10e (bed partner items)
    "q10a": null, "q10b": null, "q10c": null, "q10d": null, "q10e": null,
  };

  // Q10 (partner/roommate presence)
  int? _q10Partner; // 0: none, 1: other room, 2: same room not same bed, 3: same bed
  final TextEditingController _q10eText = TextEditingController(); // description for 10e

  // Helper for partner presence
  bool get _hasPartner => _q10Partner != null && _q10Partner != 0;

  // Keys set for Q10a–Q10e
  final Set<String> q10Keys = {'q10a', 'q10b', 'q10c', 'q10d', 'q10e'};

  bool _loading = false;

  // ---- Submit ----
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate() || sleepTime == null || wakeTime == null) return;

    setState(() => _loading = true);

    final prefs = await SharedPreferences.getInstance();
    // ίδιο κλειδί όπως στο login που μου έδωσες
    final token = prefs.getString("access_token");

    final Map<String, dynamic> answers = {
      // Q1–Q4
      "q1": _formatTime(sleepTime!),
      "q2": int.parse(q2Controller.text),
      "q3": _formatTime(wakeTime!),
      "q4": double.parse(q4Controller.text),
    };

    // Q5a–Q5j, Q6–Q9: required -> send value (fallback 0 to keep previous behavior)
    // Q10a–Q10e: optional -> send ONLY if has partner AND value != null
    dropdownAnswers.forEach((key, value) {
      final isQ10 = q10Keys.contains(key);
      if (isQ10) {
        if (_hasPartner && value != null) {
          answers[key] = value;
        }
      } else {
        answers[key] = value ?? 0;
      }
    });

    // Q10 partner/roommate presence itself is optional; include only if set
    if (_q10Partner != null) {
      answers["q10_partner"] = _q10Partner;
    }

    // Q10e free text only when partner exists and there is content
    if (_hasPartner && _q10eText.text.trim().isNotEmpty) {
      answers["q10e_text"] = _q10eText.text.trim();
    }

    final url = "${dotenv.env['BASE_URL']}/psqi";
    final headers = {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
    final body = json.encode({"answers": answers});

    print("📤 Submitting PSQI form...");
    print("🔗 URL: $url");
    print("🧠 Token: ${token?.substring(0, 10)}...");
    print("📦 Body:\n$body");
    print("📨 Headers: $headers");

    try {
      final response = await http.post(Uri.parse(url), headers: headers, body: body);
      print("✅ Status code: ${response.statusCode}");
      print("🔽 Response body: ${response.body}");

      if (response.statusCode == 200) {
        // === Trigger agent μετά το επιτυχές submit ===
        final agentUrl = "http://localhost:8000/agent/evaluate_psqi";
        print("⚡ Calling agent evaluation at $agentUrl");
        final agentResp = await http.post(Uri.parse(agentUrl), headers: headers);

        print("🤖 AGENT status: ${agentResp.statusCode}");
        print("🤖 AGENT result: ${agentResp.body}");

        setState(() => _loading = false);

        if (agentResp.statusCode == 200) {
          final result = json.decode(agentResp.body);
          Navigator.pushReplacementNamed(context, '/psqi_result', arguments: result);
        } else {
          final error = _safeJson(agentResp.body);
          _showError("Agent Error", error["detail"]?.toString() ?? "Unknown error");
        }
      } else {
        setState(() => _loading = false);
        final error = _safeJson(response.body);
        _showError("Error", error["detail"]?.toString() ?? "Unknown error");
      }
    } catch (e) {
      setState(() => _loading = false);
      print("❌ Exception: $e");
      _showError("Network Error", e.toString());
    }
  }

  Map<String, dynamic> _safeJson(String body) {
    try { return json.decode(body) as Map<String, dynamic>; } catch (_) { return {"detail": body}; }
  }

  void _showError(String title, String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(title: Text(title), content: Text(msg)),
    );
  }

  // ---- Helpers ----
  String _formatTime(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  Future<void> _pickTime(bool isSleep) async {
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (picked != null) {
      setState(() {
        if (isSleep) {
          sleepTime = picked;
        } else {
          wakeTime = picked;
        }
      });
    }
  }

  // ===== Dropdown builders with required/enabled params =====
  Widget _buildDropdown(
    String label,
    String key, {
    bool required = true,
    bool enabled = true,
  }) {
    return DropdownButtonFormField<int>(
      decoration: InputDecoration(labelText: label),
      value: dropdownAnswers[key],
      items: const [
        DropdownMenuItem(value: 0, child: Text("0 - Not during past month")),
        DropdownMenuItem(value: 1, child: Text("1 - Less than once a week")),
        DropdownMenuItem(value: 2, child: Text("2 - Once or twice a week")),
        DropdownMenuItem(value: 3, child: Text("3 - Three or more times a week")),
      ],
      onChanged: enabled ? (value) => setState(() => dropdownAnswers[key] = value) : null,
      validator: (val) {
        if (!required) return null;
        return val == null ? "Required" : null;
      },
    );
  }

  Widget _buildDropdown2(
    String label,
    String key, {
    bool required = true,
    bool enabled = true,
  }) {
    return DropdownButtonFormField<int>(
      decoration: InputDecoration(labelText: label),
      value: dropdownAnswers[key],
      items: const [
        DropdownMenuItem(value: 0, child: Text("0 - Very good")),
        DropdownMenuItem(value: 1, child: Text("1 - Fairly Good")),
        DropdownMenuItem(value: 2, child: Text("2 - Fairly Bad")),
        DropdownMenuItem(value: 3, child: Text("3 - Very Bad")),
      ],
      onChanged: enabled ? (value) => setState(() => dropdownAnswers[key] = value) : null,
      validator: (val) {
        if (!required) return null;
        return val == null ? "Required" : null;
      },
    );
  }

  Widget _buildDropdown3(
    String label,
    String key, {
    bool required = true,
    bool enabled = true,
  }) {
    return DropdownButtonFormField<int>(
      decoration: InputDecoration(labelText: label),
      value: dropdownAnswers[key],
      items: const [
        DropdownMenuItem(value: 0, child: Text("0 - No problem at all")),
        DropdownMenuItem(value: 1, child: Text("1 - Only a very slight problem")),
        DropdownMenuItem(value: 2, child: Text("2 - Somewhat of a problem")),
        DropdownMenuItem(value: 3, child: Text("3 - A very big problem")),
      ],
      onChanged: enabled ? (value) => setState(() => dropdownAnswers[key] = value) : null,
      validator: (val) {
        if (!required) return null;
        return val == null ? "Required" : null;
      },
    );
  }

  @override
  void dispose() {
    q2Controller.dispose();
    q4Controller.dispose();
    _q10eText.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("PSQI Form")),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Stack(
            children: [
              Opacity(
                opacity: _loading ? 0.5 : 1,
                child: AbsorbPointer(
                  absorbing: _loading,
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // ---- Section 1: Q1–Q4 ----
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                ListTile(
                                  title: const Text("Q1: Usual bed time"),
                                  subtitle: Text(sleepTime != null ? _formatTime(sleepTime!) : "Not selected"),
                                  trailing: const Icon(Icons.access_time),
                                  onTap: () => _pickTime(true),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: q2Controller,
                                  decoration: const InputDecoration(labelText: "Q2: Minutes to fall asleep"),
                                  keyboardType: TextInputType.number,
                                  validator: (val) => val == null || val.isEmpty ? "Required" : null,
                                ),
                                const SizedBox(height: 12),
                                ListTile(
                                  title: const Text("Q3: Usual wake time"),
                                  subtitle: Text(wakeTime != null ? _formatTime(wakeTime!) : "Not selected"),
                                  trailing: const Icon(Icons.access_time),
                                  onTap: () => _pickTime(false),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: q4Controller,
                                  decoration: const InputDecoration(labelText: "Q4: Hours of actual sleep"),
                                  keyboardType: TextInputType.number,
                                  validator: (val) => val == null || val.isEmpty ? "Required" : null,
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ---- Section 2: Q5a–Q5j ----
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Q5: Sleep troubles due to...", style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                _buildDropdown("Q5a: Can't fall asleep in 30 mins", "q5a"),
                                _buildDropdown("Q5b: Wake up during night", "q5b"),
                                _buildDropdown("Q5c: Go to bathroom", "q5c"),
                                _buildDropdown("Q5d: Breathing discomfort", "q5d"),
                                _buildDropdown("Q5e: Cough/snore loudly", "q5e"),
                                _buildDropdown("Q5f: Feeling cold", "q5f"),
                                _buildDropdown("Q5g: Feeling hot", "q5g"),
                                _buildDropdown("Q5h: Bad dreams", "q5h"),
                                _buildDropdown("Q5i: Pain", "q5i"),
                                _buildDropdown("Q5j: Other reason", "q5j"),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ---- Section 3: Q6–Q9 ----
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                _buildDropdown2("Q6: Overall sleep quality", "q6"),
                                _buildDropdown("Q7: Took sleep medication", "q7"),
                                _buildDropdown("Q8: Trouble staying awake (daily)", "q8"),
                                _buildDropdown3("Q9: Trouble with enthusiasm", "q9"),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ---- Section 4: Q10 (Bed partner/Roommate) ----
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Q10: Do you have a bed partner or roommate?", style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                RadioListTile<int>(
                                  value: 0,
                                  groupValue: _q10Partner,
                                  title: const Text("No bed partner or roommate"),
                                  onChanged: (v) => setState(() {
                                    _q10Partner = v;
                                    if (!_hasPartner) {
                                      for (final k in q10Keys) {
                                        dropdownAnswers[k] = null; // clear optional fields
                                      }
                                      _q10eText.clear();
                                    }
                                  }),
                                ),
                                RadioListTile<int>(
                                  value: 1,
                                  groupValue: _q10Partner,
                                  title: const Text("Partner/roommate in other room"),
                                  onChanged: (v) => setState(() => _q10Partner = v),
                                ),
                                RadioListTile<int>(
                                  value: 2,
                                  groupValue: _q10Partner,
                                  title: const Text("Partner in same room, but not same bed"),
                                  onChanged: (v) => setState(() => _q10Partner = v),
                                ),
                                RadioListTile<int>(
                                  value: 3,
                                  groupValue: _q10Partner,
                                  title: const Text("Partner in same bed"),
                                  onChanged: (v) => setState(() => _q10Partner = v),
                                ),
                                const SizedBox(height: 12),
                                const Divider(),
                                const SizedBox(height: 6),
                                const Text(
                                  "If you have a partner/roommate, how often in the past month have you had:",
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 10),
                                _buildDropdown("Q10a: Loud snoring", "q10a", required: false, enabled: _hasPartner),
                                _buildDropdown("Q10b: Long pauses between breaths while asleep", "q10b", required: false, enabled: _hasPartner),
                                _buildDropdown("Q10c: Legs twitching or jerking while you sleep", "q10c", required: false, enabled: _hasPartner),
                                _buildDropdown("Q10d: Episodes of disorientation/confusion during sleep", "q10d", required: false, enabled: _hasPartner),
                                _buildDropdown("Q10e: Other restlessness while you sleep", "q10e", required: false, enabled: _hasPartner),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _q10eText,
                                  enabled: _hasPartner,
                                  decoration: const InputDecoration(
                                    labelText: "Q10e description (optional)",
                                    hintText: "Describe the other restlessness",
                                  ),
                                  maxLines: 2,
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _submitForm,
                          child: const Text("Submit"),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_loading)
                Positioned.fill(
                  child: Container(
                    color: Colors.black45,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
