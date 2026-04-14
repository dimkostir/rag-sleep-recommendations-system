import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter_application_1/config.dart';

class SleepEntryPage extends StatefulWidget {
  const SleepEntryPage({super.key});

  @override
  State<SleepEntryPage> createState() => _SleepEntryPageState();
}

class _SleepEntryPageState extends State<SleepEntryPage> {
  final _formKey = GlobalKey<FormState>();

  final sleepDurationController = TextEditingController();
  final awakeningsController = TextEditingController();
  final caffeineController = TextEditingController();
  final screenTimeController = TextEditingController();
  final stressController = TextEditingController();

  String afterSleepFeeling = '';
  String roomLight = '';
  TimeOfDay? sleepTime;
  TimeOfDay? wakeTime;

  String message = '';
  bool isLoading = false;

  // Dropdown sleep feeling options
  final List<String> feelingOptions = [
    'Bad',
    'Average',
    'Good',
    'Very Good',
  ];
  //Dropdown Room Light
  final List<String> roomLightOptions = [
    'Total darkness',
    'Minimal light',
    'Bright room',
  ];

  // Formatting TimeOfDay as HH:mm
  String? _formatTimeOfDay(TimeOfDay? t) =>
      t == null ? null : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  // Διαβάζει το JWT token από shared_preferences
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<void> handleSubmit() async {
    if (!_formKey.currentState!.validate() ||
        afterSleepFeeling.isEmpty ||
        sleepTime == null ||
        wakeTime == null) {
      setState(() => message = '❌ Fill all fields!');
      return;
    }

    setState(() {
      isLoading = true;
      message = '';
    });

    final formData = {
      "sleep_duration": double.tryParse(sleepDurationController.text.trim()) ?? 0.0,
      "awakenings": int.tryParse(awakeningsController.text.trim()) ?? 0,
      "caffeine_intake": int.tryParse(caffeineController.text.trim()) ?? 0,
      "screen_time": double.tryParse(screenTimeController.text.trim()) ?? 0.0,
      "stress_level": int.tryParse(stressController.text.trim()) ?? 0,
      "after_sleep_feeling": afterSleepFeeling,
      "room_light":roomLight,
      "sleep_time": _formatTimeOfDay(sleepTime) ?? "",
      "wake_time": _formatTimeOfDay(wakeTime) ?? "",
    };

    try {
      final token = await _getToken();
      final url = Uri.parse('${AppConfig.baseUrl}/sleep_entry'); 

      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
        body: jsonEncode(formData),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        setState(() => message = '✅ ${data["message"] ?? "Submitted!"}');
        await Future.delayed(const Duration(milliseconds: 400)); 
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/evaluation_result');
      } else {
        setState(() => message = '❌ ${data["detail"] ?? "Submission failed."}');
      }
    } catch (e) {
      setState(() => message = '❌ Network error.');
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    sleepDurationController.dispose();
    awakeningsController.dispose();
    caffeineController.dispose();
    screenTimeController.dispose();
    stressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width < 600 ? double.infinity : 430.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Enter Your Sleep Data'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Card(
              elevation: 14,
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const Icon(Icons.nights_stay, color: Colors.deepPurple, size: 48),
                      const SizedBox(height: 20),
                      const Text(
                        '💤 Enter Your Sleep Data',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.deepPurple,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 22),

                      // Sleep Duration
                      _buildNumberField(controller: sleepDurationController, label: 'Sleep Duration (hours)', step: 0.1, min: 0, validator: 'Enter a number'),
                      // Awakenings
                      _buildNumberField(controller: awakeningsController, label: 'Awakenings (# times)', min: 0, validator: 'Enter a number'),
                      // Caffeine
                      _buildNumberField(controller: caffeineController, label: 'Caffeine Intake (# cups)', min: 0, validator: 'Enter a number'),
                      // Screen Time
                      _buildNumberField(controller: screenTimeController, label: 'Screen Time Before Bed (hours)', step: 0.1, min: 0, validator: 'Enter a number'),
                      // Stress Level
                      _buildNumberField(controller: stressController, label: 'Stress Level (1–10)', min: 1, max: 10, validator: '1-10'),

                      // After Sleep Feeling (Dropdown)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: DropdownButtonFormField<String>(
                          value: afterSleepFeeling.isEmpty ? null : afterSleepFeeling,
                          decoration: InputDecoration(
                            labelText: 'After-Sleep Feeling',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: feelingOptions
                              .map((feeling) => DropdownMenuItem(
                                    value: feeling,
                                    child: Text(feeling),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            setState(() => afterSleepFeeling = val ?? '');
                          },
                          validator: (val) => val == null || val.isEmpty ? 'Select a feeling' : null,
                        ),
                      ),
    
    
                     //Room Light
                      Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: DropdownButtonFormField<String>(
                          value: roomLight.isEmpty ? null : roomLight,
                          decoration: InputDecoration(
                            labelText: 'Room Light',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: roomLightOptions
                              .map((light) => DropdownMenuItem(
                                    value: light,
                                    child: Text(light),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            setState(() => roomLight = val ?? '');
                          },
                          validator: (val) => val == null || val.isEmpty ? 'Room Light' : null,
                        ),
                      ),
       
       
       
                      // Sleep Time
                      _buildTimePicker(
                        context: context,
                        label: 'Sleep Time',
                        value: sleepTime,
                        onTap: () async {
                          final t = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );
                          if (t != null) setState(() => sleepTime = t);
                        },
                      ),
                      // Wake Time
                      _buildTimePicker(
                        context: context,
                        label: 'Wake Time',
                        value: wakeTime,
                        onTap: () async {
                          final t = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );
                          if (t != null) setState(() => wakeTime = t);
                        },
                      ),
                      const SizedBox(height: 26),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : handleSubmit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text('Submit', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      if (message.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 18),
                          child: Text(
                            message,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: message.startsWith('✅') ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
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

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    double? step,
    int? min,
    int? max,
    String? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        validator: (val) {
          if (val == null || val.isEmpty) return validator ?? 'Required';
          final number = double.tryParse(val);
          if (number == null) return 'Enter a valid number';
          if (min != null && number < min) return 'Min $min';
          if (max != null && number > max) return 'Max $max';
          return null;
        },
      ),
    );
  }

  Widget _buildTimePicker({
    required BuildContext context,
    required String label,
    required TimeOfDay? value,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value == null ? '--:--' : '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontSize: 16,
                  color: value == null ? Colors.grey : Colors.black,
                ),
              ),
              const Icon(Icons.access_time, color: Colors.deepPurple),
            ],
          ),
        ),
      ),
    );
  }
}
