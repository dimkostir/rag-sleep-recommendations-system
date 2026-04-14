import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_application_1/config.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final usernameController = TextEditingController();
  final nameController = TextEditingController();
  final surnameController = TextEditingController();
  final ageController = TextEditingController();
  final weightController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  String message = '';
  bool isLoading = false;

  // Exercise dropdown
  String? selectedExercise;
  final List<String> exerciseOptions = ['None', 'Light', 'Moderate', 'Heavy'];

  // Gender dropdown
  String? selectedGender;
  final List<String> genderOptions = ['Male', 'Female'];

  // Nutrition checkboxes
  final List<String> nutritionOptions = ['Vegan', 'Vegetarian', 'Omnivore', 'Keto'];
  List<String> selectedNutritions = [];

  Future<void> handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
      message = '';
    });

    final formData = {
      "username": usernameController.text.trim(),
      "name": nameController.text.trim(),
      "surname": surnameController.text.trim(),
      "age": int.tryParse(ageController.text.trim()) ?? 0,
      "weight": double.tryParse(weightController.text.trim()) ?? 0.0,
      "email": emailController.text.trim(),
      "password": passwordController.text,
      "exercise": selectedExercise ?? "",
      "nutrition_habits": selectedNutritions.join(","),
      "gender": selectedGender ?? "",
    };

    try {
      final url = Uri.parse('${AppConfig.baseUrl}/register');
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(formData),
      );

      Map<String, dynamic> data = {};
      try {
        if (response.body.isNotEmpty) {
          data = jsonDecode(response.body);
        }
      } catch (_) {}

      if (response.statusCode == 200 || response.statusCode == 200) { // safeguard
        setState(() => message = '✅ ${data["message"] ?? "Registration successful!"}');
        await Future.delayed(const Duration(seconds: 1));
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/login_page');
      } else {
        setState(() => message = '❌ ${data["detail"] ?? "Registration failed"}');
      }
    } catch (e) {
      setState(() => message = '❌ Something went wrong (maybe no connection?)');
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    usernameController.dispose();
    nameController.dispose();
    surnameController.dispose();
    ageController.dispose();
    weightController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width < 600 ? double.infinity : 400.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Register'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person_add_alt_1, size: 48, color: Colors.deepPurple),
                  const SizedBox(height: 16),
                  const Text(
                    'Fill out the registration form',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // ----------- CARD 1: Credentials & Personal -----------
                        Card(
                          elevation: 12,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                            child: Column(
                              children: [
                                _buildTextField(
                                  controller: usernameController,
                                  label: 'Username',
                                  validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                                ),
                                _buildTextField(
                                  controller: emailController,
                                  label: 'Email',
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                                ),
                                _buildTextField(
                                  controller: nameController,
                                  label: 'First Name',
                                  validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                                ),
                                _buildTextField(
                                  controller: surnameController,
                                  label: 'Last Name',
                                  validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                                ),
                                _buildTextField(
                                  controller: passwordController,
                                  label: 'Password',
                                  obscureText: true,
                                  validator: (val) => val == null || val.length < 4
                                      ? 'At least 4 characters'
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ----------- CARD 2: Profile & Lifestyle -----------
                        Card(
                          elevation: 12,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                            child: Column(
                              children: [
                                // Gender
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: DropdownButtonFormField<String>(
                                    value: selectedGender,
                                    decoration: InputDecoration(
                                      labelText: 'Gender',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    items: genderOptions
                                        .map((g) => DropdownMenuItem(
                                              value: g,
                                              child: Text(g),
                                            ))
                                        .toList(),
                                    onChanged: (v) => setState(() => selectedGender = v),
                                  ),
                                ),
                                _buildTextField(
                                  controller: ageController,
                                  label: 'Age',
                                  keyboardType: TextInputType.number,
                                  validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                                ),
                                _buildTextField(
                                  controller: weightController,
                                  label: 'Weight',
                                  keyboardType: TextInputType.number,
                                  validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: DropdownButtonFormField<String>(
                                    value: selectedExercise,
                                    decoration: InputDecoration(
                                      labelText: 'Exercise Level',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    items: exerciseOptions
                                        .map((option) => DropdownMenuItem(
                                              value: option,
                                              child: Text(option),
                                            ))
                                        .toList(),
                                    onChanged: (value) {
                                      setState(() => selectedExercise = value);
                                    },
                                    validator: (value) =>
                                        value == null || value.isEmpty ? 'Required' : null,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Nutrition Habits',
                                      style: TextStyle(
                                        color: Colors.deepPurple.shade700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                Column(
                                  children: nutritionOptions.map((option) {
                                    return CheckboxListTile(
                                      title: Text(option),
                                      value: selectedNutritions.contains(option),
                                      onChanged: (checked) {
                                        setState(() {
                                          if (checked == true) {
                                            selectedNutritions.add(option);
                                          } else {
                                            selectedNutritions.remove(option);
                                          }
                                        });
                                      },
                                      controlAffinity: ListTileControlAffinity.leading,
                                      activeColor: Colors.deepPurple,
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),
                        
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            'By registering, I consent to the processing of the data I enter exclusively for the operation of the application. '
                            'My data is stored securely and will not be shared with third parties without my express consent. ',
                            style: const TextStyle(fontSize: 12.5, color: Colors.black54, height: 1.35),
                            textAlign: TextAlign.left,
                          ),
                        ),

                        // Submit Button (ίδιο)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Icon(Icons.app_registration),
                            label: const Text('Register', style: TextStyle(fontSize: 18)),
                            onPressed: isLoading ? null : handleSubmit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),

                        if (message.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            message,
                            style: TextStyle(
                              color: message.startsWith('✅') ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.deepPurple),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
          ),
        ),
      ),
    );
  }
}
