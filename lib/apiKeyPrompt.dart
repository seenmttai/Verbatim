import 'package:flutter/material.dart';
import 'package:organiser/main.dart'; // Import for dbHelper access
import 'globals.dart' as globals;

class ApiKeyPrompt extends StatefulWidget {
  const ApiKeyPrompt({super.key});

  @override
  State<ApiKeyPrompt> createState() => _ApiKeyPromptState();
}

class _ApiKeyPromptState extends State<ApiKeyPrompt> {
  final _apiKeyController = TextEditingController();

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enter Gemini API Key', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blueGrey[700], // Darker shade for AppBar
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Please enter your Gemini API key below:',
              style: TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _apiKeyController,
              obscureText: true, // Hide the API key
              decoration: InputDecoration(
                hintText: 'Your API key',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                prefixIcon: const Icon(Icons.vpn_key),
                filled: true,
                fillColor: Colors.grey[200],
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () async {
                final apiKey = _apiKeyController.text.trim();
                if (apiKey.isNotEmpty) {
                  await dbHelper.insertRow('APITable', {'APIKey': apiKey});
                  print("API key saved: $apiKey");
                  globals.APIKey = apiKey;
                  Navigator.pop(context); // Go back to the previous screen
                } else {
                  // Show an error message if the API key is empty
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid API key!')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey, // Consistent color scheme
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                textStyle: const TextStyle(fontSize: 18),
              ),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}