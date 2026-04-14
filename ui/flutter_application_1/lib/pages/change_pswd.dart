import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_application_1/config.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();

  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();

  bool _showOld = false;
  bool _showNew = false;

  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    super.dispose();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _error = null;
      _submitting = true;
    });

    try {
      final token = await _getToken();
      if (token == null) {
        setState(() => _error = 'Not authenticated. Please sign in again.');
        return;
      }

      // Προσαρμόστε αν το endpoint είναι διαφορετικό στο backend σας
      final url = Uri.parse('${AppConfig.baseUrl}/change_pswd');

      final res = await http.post(
        url,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          if (AppConfig.baseUrl.contains('ngrok'))
            'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'old_password': _oldCtrl.text.trim(),
          'new_password': _newCtrl.text.trim(),
        }),
      );

      final ct = res.headers['content-type'] ?? '';

      if (res.statusCode == 200 || res.statusCode == 204) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password changed successfully')),
        );
        Navigator.pop(context);
        return;
      }

      if (ct.contains('application/json')) {
        final data = jsonDecode(res.body);
        final msg = data['detail']?.toString() ??
            data['message']?.toString() ??
            'Error ${res.statusCode}';
        setState(() => _error = msg);
      } else {
        setState(() => _error = 'Error ${res.statusCode}: ${res.body}');
      }
    } catch (e) {
      setState(() => _error = 'Request failed: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 700;
    final maxWidth = isWide ? 520.0 : 430.0;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Settings'),
        automaticallyImplyLeading: true,
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
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Card(
              elevation: 14,
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              color: Colors.deepPurple.shade50,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_outline, color: Colors.deepPurple, size: 54),
                      const SizedBox(height: 12),
                      const Text(
                        'Update your password',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.deepPurple,
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (_error != null)
                        Card(
                          color: Colors.red.shade50,
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: Colors.red, size: 22),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: const TextStyle(color: Colors.red, fontSize: 14.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // old pswd
                      _LabeledField(
                        label: 'Current password',
                        child: TextFormField(
                          controller: _oldCtrl,
                          obscureText: !_showOld,
                          decoration: InputDecoration(
                            hintText: 'Enter your current password',
                            prefixIcon: const Icon(Icons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _showOld ? Icons.visibility_off : Icons.visibility,
                                color: Colors.deepPurple,
                              ),
                              onPressed: () => setState(() => _showOld = !_showOld),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // new pswd
                      _LabeledField(
                        label: 'New password',
                        child: TextFormField(
                          controller: _newCtrl,
                          obscureText: !_showNew,
                          decoration: InputDecoration(
                            hintText: 'Enter a new password',
                            prefixIcon: const Icon(Icons.lock_reset),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _showNew ? Icons.visibility_off : Icons.visibility,
                                color: Colors.deepPurple,
                              ),
                              onPressed: () => setState(() => _showNew = !_showNew),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          validator: (v) {
                            final val = v?.trim() ?? '';
                            if (val.isEmpty) return 'Required';
                            if (val == _oldCtrl.text.trim()) {
                              return 'New password must be different';
                            }
                            return null;
                          },
                        ),
                      ),

                      const SizedBox(height: 22),

                      // Submit
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: _submitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(Colors.white),
                                  ),
                                )
                              : const Icon(Icons.save_alt_rounded),
                          label: Text(
                            _submitting ? 'Updating…' : 'Update Password',
                            style: const TextStyle(fontSize: 16.5),
                          ),
                          onPressed: _submitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
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
      ),
    );
  }
}

/* ------- Helper για labeled fields ώστε να ταιριάζει το look ------- */
class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;

  const _LabeledField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.deepPurple.shade700,
            fontWeight: FontWeight.w600,
            letterSpacing: .2,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}
