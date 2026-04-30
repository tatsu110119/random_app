import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '乱数ルーレット',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.pinkAccent,
        scaffoldBackgroundColor: const Color(0xFFFFF7FB),
      ),
      home: const RandomPage(),
    );
  }
}

class RandomPage extends StatefulWidget {
  const RandomPage({super.key});

  @override
  State<RandomPage> createState() => _RandomPageState();
}

class _RandomPageState extends State<RandomPage> {
  final minController = TextEditingController(text: "-20");
  final maxController = TextEditingController(text: "20");
  final stepController = TextEditingController(text: "5");

  final random = Random();
  final rollingPlayer = AudioPlayer();
  final finishPlayer = AudioPlayer();

  List<int> history = [];
  int? result;
  bool isRolling = false;
  bool hasFinalResult = false;

  @override
  void initState() {
    super.initState();
    loadHistory();
  }

  Future<void> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('history') ?? [];
    setState(() {
      history = saved.map(int.parse).toList();
    });
  }

  Future<void> saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'history',
      history.map((e) => e.toString()).toList(),
    );
  }

  Future<void> generate() async {
    if (isRolling) return;

    final min = int.tryParse(minController.text);
    final max = int.tryParse(maxController.text);
    final step = int.tryParse(stepController.text);

    if (min == null || max == null || step == null || step <= 0 || min > max) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("入力が不正です")),
      );
      return;
    }

    final list = <int>[];
    for (int i = min; i <= max; i += step) {
      list.add(i);
    }

    setState(() {
      isRolling = true;
      hasFinalResult = false;
    });

    await rollingPlayer.setReleaseMode(ReleaseMode.loop);
    await rollingPlayer.play(AssetSource('sounds/rolling.mp3'));

    final stopwatch = Stopwatch()..start();

    while (stopwatch.elapsedMilliseconds < 13000) {
      final elapsed = stopwatch.elapsedMilliseconds;
      int delay;

      if (elapsed < 5000) {
        delay = 350;
      } else if (elapsed < 8000) {
        delay = 45;
      } else {
        final t = (elapsed - 8000) / 5000;
        delay = (60 + 420 * t).toInt();
      }

      setState(() {
        result = list[random.nextInt(list.length)];
      });

      await Future.delayed(Duration(milliseconds: delay));
    }

    stopwatch.stop();
    await rollingPlayer.stop();

    final finalValue = list[random.nextInt(list.length)];

    setState(() {
      result = finalValue;
      history.insert(0, finalValue);
      isRolling = false;
      hasFinalResult = true;
    });

    await finishPlayer.play(AssetSource('sounds/finish.mp3'));
    saveHistory();
  }

  @override
  void dispose() {
    minController.dispose();
    maxController.dispose();
    stepController.dispose();
    rollingPlayer.dispose();
    finishPlayer.dispose();
    super.dispose();
  }

  InputDecoration cuteInput(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = hasFinalResult ? 92.0 : 52.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('🎀 乱数ルーレット 🎀'),
        centerTitle: true,
        backgroundColor: const Color(0xFFFFD6EA),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEAF4),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: minController,
                      decoration: cuteInput('最小値', Icons.remove_circle_outline),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: maxController,
                      decoration: cuteInput('最大値', Icons.add_circle_outline),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: stepController,
                      decoration: cuteInput('間隔', Icons.straighten),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              AnimatedScale(
                scale: isRolling ? 1.05 : hasFinalResult ? 1.2 : 1.0,
                duration: const Duration(milliseconds: 250),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 36),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(36),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFFB8DA),
                        Color(0xFFFFE4F2),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.pinkAccent.withOpacity(0.25),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 300),
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF7A2450),
                    ),
                    child: Text(
                      result == null ? '？' : '$result',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              FilledButton.icon(
                onPressed: isRolling ? null : generate,
                icon: const Icon(Icons.auto_awesome),
                label: Text(isRolling ? 'くるくる中…' : 'まわす ✨'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 58),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),

              const SizedBox(height: 22),

              const Text(
                '📜 履歴',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF7A2450),
                ),
              ),

              const SizedBox(height: 8),

              Expanded(
                child: history.isEmpty
                    ? const Center(child: Text("まだ履歴はありません 🐣"))
                    : ListView.builder(
                        itemCount: history.length,
                        itemBuilder: (context, index) {
                          return Card(
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFFFFD6EA),
                                child: Text('${index + 1}'),
                              ),
                              title: Text(
                                history[index].toString(),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}