import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_application_1/config.dart';

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  bool isLoggedIn = false;
  String displayName = 'there';
  int _navIndex = 0; // 0: Home, 1: Settings, 2: Info

  // Mini dashboard
  bool dashLoading = false;
  String? dashError;
  int? lastLevel;
  double? lastAverage; // CHANGED: double for average_score

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _checkLoginAndName();
    if (isLoggedIn) {
      await _fetchTodayHistorySummary();
    }
  }

  Future<void> _fetchTodayHistorySummary() async {
    setState(() {
      dashLoading = true;
      dashError = null;
      lastLevel = null;
      lastAverage = null;
    });

    try {
      final token = await _getToken();
      if (token == null) {
        setState(() => dashError = 'Not authenticated');
        return;
      }

      // Call /stats (object response, not list)
      final url = Uri.parse(AppConfig.baseUrl).replace(path: '/stats');

      final res = await http.get(url, headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
        if (AppConfig.baseUrl.contains('ngrok'))
          'ngrok-skip-browser-warning': 'true',
      });

      final ct = res.headers['content-type'] ?? '';
      if (res.statusCode != 200 || !ct.contains('application/json')) {
        setState(() => dashError = 'No recent data');
        return;
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;

      setState(() {
        lastLevel = _asInt(data['level']);
        lastAverage = _asDouble(data['average_score']);

        // If backend returns name, prefer it
        final n = (data['name'] as String?)?.trim();
        if (n != null && n.isNotEmpty) {
          displayName = n;
        }
      });
    } catch (e) {
      setState(() => dashError = 'Error: $e');
    } finally {
      setState(() => dashLoading = false);
    }
  }

  // helpers for safe casting
  int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is String) return int.tryParse(v);
    return null;
  }

  double? _asDouble(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  Future<void> _checkLoginAndName() async {
    final prefs = await SharedPreferences.getInstance();
    final logged = prefs.containsKey('access_token');
    final name =
        prefs.getString('display_name') ??
        prefs.getString('name') ??
        prefs.getString('username') ??
        prefs.getString('email') ??
        'there';
    final pretty = name.contains('@') ? name.split('@').first : name;

    setState(() {
      isLoggedIn = logged;
      displayName = pretty.trim().isEmpty ? 'there' : pretty.trim();
    });
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/home_page', (route) => false);
  }

  bool get _isDayTime {
    final h = DateTime.now().hour;
    return h >= 6 && h < 18;
  }

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 600;
    final maxWidth = isNarrow ? double.infinity : 430.0;

    return Scaffold(
      // Fancy top bar (gradient + rounded bottom)
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: const Text('Main Menu'),
        actions: [
          if (isLoggedIn)
            IconButton(
              tooltip: 'Logout',
              icon: const Icon(Icons.logout_rounded),
              onPressed: _logout,
            ),
        ],
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.deepPurple,
                Colors.deepPurple.shade400,
              ],
            ),
          ),
        ),
        elevation: 8,
      ),

      // Bottom navbar unchanged
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _navIndex,
        onTap: (i) {
          setState(() => _navIndex = i);
          if (i == 0) {
            // Home
          } else if (i == 1) {
            Navigator.pushNamed(context, '/change_pswd'); // ensure route exists
          } else if (i == 2) {
            Navigator.pushNamed(context, '/info');
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.deepPurple.shade200,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'Settings'),
          BottomNavigationBarItem(icon: Icon(Icons.info_outline_rounded), label: 'Info'),
        ],
      ),

      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // GREETING
                  Card(
                    elevation: 6,
                    color: Colors.deepPurple.shade50,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                      side: BorderSide(
                        color: Colors.deepPurple.withOpacity(0.12),
                        width: 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                      child: Row(
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.shade100,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              _isDayTime ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                              color: Colors.deepPurple,
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // "Hello, " + name NEXT TO it
                                Row(
                                  children: [
                                    const Text(
                                      'Hello, ',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Flexible(
                                      child: Text(
                                        displayName,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.deepPurple.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _isDayTime
                                      ? 'Ready for a productive day?'
                                      : 'Have a restful evening.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.deepPurple.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // MINI DASHBOARD (Level + Average)
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: dashLoading
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 3),
                                ),
                                SizedBox(width: 10),
                                Text('Loading latest stats...'),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _Kpi(
                                  icon: Icons.stars_rounded,
                                  label: 'Level',
                                  value: lastLevel != null ? 'Level $lastLevel' : '—',
                                ),
                                Container(
                                  width: 1,
                                  height: 30,
                                  color: Colors.deepPurple.withOpacity(0.12),
                                ),
                                _Kpi(
                                  icon: Icons.timeline_rounded,
                                  label: 'Average',
                                  value: lastAverage != null
                                      ? '${lastAverage!.toStringAsFixed(0)} / 100'
                                      : '—',
                                ),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ACTION BUTTONS — 2x2 grid
                  GridView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisExtent: 80,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    children: [
                      _ActionTile.filled(
                        icon: Icons.add_circle_outline,
                        label: 'Enter Sleep',
                        onTap: () => Navigator.pushNamed(context, '/sleep_entry'),
                      ),
                      _ActionTile.filledAlt(
                        icon: Icons.history_rounded,
                        label: 'Sleep History',
                        onTap: () => Navigator.pushNamed(context, '/evaluation_history'),
                      ),
                      _ActionTile.outlined(
                        icon: Icons.fact_check_rounded,
                        label: 'PSQI',
                        onTap: () => Navigator.pushNamed(context, '/psqi_page'),
                      ),
                      _ActionTile.outlined(
                        icon: Icons.history_toggle_off_rounded,
                        label: 'PSQI History',
                        onTap: () => Navigator.pushNamed(context, '/psqi_history'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // FULL-WIDTH TIP CARD (below PSQI row)
                  _TipCard(text: _tipOfTheDay()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _tipOfTheDay() {
    const tips = [
      "Power down screens 60–90 minutes before bed.",
      "Keep your bedroom cool, dark, and quiet.",
      "Avoid caffeine after 3 pm.",
      "Aim for a consistent sleep & wake time.",
      "Do a 10-minute calming routine before bed.",
      "Limit naps to 20–30 minutes.",
      "Get morning daylight exposure.",
      "Finish dinner at least 2–3 hours before bed.",
      "Keep the bed for sleep and intimacy only.",
      "If you can’t sleep, get up, reset, and return.",
    ];
    final d = DateTime.now();
    final idx = (d.year + d.month + d.day) % tips.length;
    return tips[idx];
  }
}

/// ---------- Sub-widgets ----------

class _Kpi extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _Kpi({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.deepPurple, size: 22),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.deepPurple.withOpacity(0.9),
                )),
            Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ],
    );
  }
}

enum _ActionTileKind { elevated, outlined }

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final ButtonStyle style;
  final _ActionTileKind kind;

  const _ActionTile._({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.style,
    required this.kind,
  });

  // Filled (primary)
  factory _ActionTile.filled({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return _ActionTile._(
      icon: icon,
      label: label,
      onTap: onTap,
      kind: _ActionTileKind.elevated,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        elevation: 3,
      ),
    );
  }

  // Filled (secondary)
  factory _ActionTile.filledAlt({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return _ActionTile._(
      icon: icon,
      label: label,
      onTap: onTap,
      kind: _ActionTileKind.elevated,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.deepPurple.shade400,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        elevation: 3,
      ),
    );
  }

  // Outlined
  factory _ActionTile.outlined({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return _ActionTile._(
      icon: icon,
      label: label,
      onTap: onTap,
      kind: _ActionTileKind.outlined,
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Colors.deepPurple, width: 1.6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 22),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );

    final btn = (kind == _ActionTileKind.outlined)
        ? OutlinedButton(onPressed: onTap, style: style, child: content)
        : ElevatedButton(onPressed: onTap, style: style, child: content);

    // Fill the grid cell fully (width/height come from the SliverGridDelegate)
    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: btn,
    );
  }
}

class _TipCard extends StatelessWidget {
  final String text;
  const _TipCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 230, 203, 240),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.deepPurple, width: 1.6),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb, color: Color.fromARGB(255, 138, 64, 165), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14.5, height: 1.3),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }
}
