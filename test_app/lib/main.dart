import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_skill/flutter_skill.dart';
import 'package:http/http.dart' as http;

void main() {
  if (kDebugMode) {
    FlutterSkillBinding.ensureInitialized();
  }
  runApp(const TestApp());
}

class TestApp extends StatelessWidget {
  const TestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Skill Test',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomePage(),
        '/detail': (context) => const DetailPage(),
        '/form': (context) => const FormPage(),
      },
    );
  }
}

// ==================== HOME PAGE ====================
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _counter = 0;
  String _apiResult = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home Page')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Button WITH text child (for assert_text #6 test)
              ElevatedButton(
                key: const Key('navigate_button'),
                onPressed: () => Navigator.pushNamed(context, '/detail'),
                child: const Text('Go to Detail'),
              ),
              const SizedBox(height: 12),

              // Button for form page navigation
              ElevatedButton(
                key: const Key('form_button'),
                onPressed: () => Navigator.pushNamed(context, '/form'),
                child: const Text('Open Form'),
              ),
              const SizedBox(height: 12),

              // Counter display + button (for basic tap test)
              Text(
                'Counter: $_counter',
                key: const Key('counter_text'),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                key: const Key('increment_button'),
                onPressed: () => setState(() => _counter++),
                child: const Text('Increment'),
              ),
              const SizedBox(height: 12),

              // TextField WITH key
              const TextField(
                key: Key('search_field'),
                decoration: InputDecoration(
                  labelText: 'Search (has key)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              // TextField WITHOUT key (for #4 focused field test)
              const TextField(
                decoration: InputDecoration(
                  labelText: 'Notes (no key)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              // API call button (for network monitoring test)
              ElevatedButton(
                key: const Key('api_button'),
                onPressed: _callApi,
                child: const Text('Call API'),
              ),
              if (_apiResult.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _apiResult,
                  key: const Key('api_result'),
                  style: const TextStyle(fontSize: 12),
                ),
              ],
              const SizedBox(height: 12),

              // Checkbox
              Row(
                children: [
                  Checkbox(
                    key: const Key('test_checkbox'),
                    value: _counter.isEven,
                    onChanged: (_) {},
                  ),
                  const Text('Counter is even'),
                ],
              ),

              // Long list for scroll testing
              ...List.generate(
                20,
                (i) => ListTile(
                  key: Key('item_$i'),
                  title: Text('Item $i'),
                  subtitle: Text('Description for item $i'),
                  onTap: () {},
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _callApi() async {
    setState(() => _apiResult = 'Loading...');
    try {
      final response = await http.get(
        Uri.parse('https://jsonplaceholder.typicode.com/posts/1'),
      );
      final data = jsonDecode(response.body);
      setState(
        () => _apiResult = 'Status: ${response.statusCode} - ${data['title']}',
      );
    } catch (e) {
      setState(() => _apiResult = 'Error: $e');
    }
  }
}

// ==================== DETAIL PAGE ====================
class DetailPage extends StatelessWidget {
  const DetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Page')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Detail Content',
              key: Key('detail_text'),
              style: TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              key: const Key('back_button'),
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== FORM PAGE ====================
class FormPage extends StatefulWidget {
  const FormPage({super.key});

  @override
  State<FormPage> createState() => _FormPageState();
}

class _FormPageState extends State<FormPage> {
  final _nameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Form Page')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // TextField WITH key
            TextField(
              key: const Key('name_field'),
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name (has key)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // TextField WITHOUT key (test #4)
            const TextField(
              decoration: InputDecoration(
                labelText: 'Email (no key)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            ElevatedButton(
              key: const Key('submit_button'),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Submitted: ${_nameController.text}')),
                );
              },
              child: const Text('Submit Form'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
