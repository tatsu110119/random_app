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
  bool soundOn = true;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedHistory = prefs.getStringList('history') ?? [];
    final savedSound = prefs.getBool('soundOn') ?? true;

    setState(() {
      history = savedHistory.map(int.parse).toList();
      soundOn = savedSound;
    });
  }

  Future<void> saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'history',
      history.map((e) => e.toString()).toList(),
    );
  }

  Future<void> saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('soundOn', soundOn);
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('history');
    setState(() => history.clear());
  }

  // スムーズ加減速
  double smoothStep(double x) => x * x * (3 - 2 * x);

  int getDelay(int elapsed) {
    const total = 13000;
    final p = elapsed / total;

    if (p < 0.4) {
      final t = smoothStep(p / 0.4);
      return (600 - 520 * t).toInt();
    } else if (p < 0.6) {
      return 40;
    } else {
      final t = smoothStep((p - 0.6) / 0.4);
      return (60 + 700 * t).toInt();
    }
  }

  Future<void> generate() async {
    if (isRolling) return;

    final min = int.tryParse(minController.text);
    final max = int.tryParse(maxController.text);
    final step = int.tryParse(stepController.text);

    if (min == null || max == null || step == null) {
      showError("入力エラー");
      return;
    }

    if (step <= 0 || min > max) {
      showError("値がおかしい");
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

    if (soundOn) {
      await rollingPlayer.setReleaseMode(ReleaseMode.loop);
      await rollingPlayer.play(AssetSource('sounds/rolling.mp3'));

      // ⭐ Safari対策：最初に予約しておく
      Future.delayed(const Duration(milliseconds: 13000), () async {
        await finishPlayer.stop();
        await finishPlayer.play(AssetSource('sounds/finish.mp3'));
      });
    }

    final stopwatch = Stopwatch()..start();

    while (stopwatch.elapsedMilliseconds < 13000) {
      final delay = getDelay(stopwatch.elapsedMilliseconds);

      setState(() {
        result = list[random.nextInt(list.length)];
      });

      await Future.delayed(Duration(milliseconds: delay));
    }

    await rollingPlayer.stop();

    final finalValue = list[random.nextInt(list.length)];

    setState(() {
      result = finalValue;
      history.insert(0, finalValue);
      isRolling = false;
      hasFinalResult = true;
    });

    await saveHistory();
  }

  void showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  void makeNegative(TextEditingController c) {
    if (!c.text.startsWith('-')) c.text = '-${c.text}';
  }

  void makePositive(TextEditingController c) {
    c.text = c.text.replaceFirst('-', '');
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

  Widget inputCard(
      String title, String emoji, TextEditingController c, Color color,
      {bool minus = true}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$emoji $title',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          TextField(
            controller: c,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
            ),
          ),
          if (minus)
            Row(
              children: [
                Expanded(
                    child: FilledButton(
                        onPressed: () => makeNegative(c),
                        child: const Text("マイナスにする"))),
                const SizedBox(width: 8),
                Expanded(
                    child: OutlinedButton(
                        onPressed: () => makePositive(c),
                        child: const Text("プラスにする"))),
              ],
            )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = hasFinalResult ? 90.0 : 50.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('🎀 乱数ルーレット 🎀'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          inputCard("最小値", "⬇️", minController, Colors.blue.shade50),
          inputCard("最大値", "⬆️", maxController, Colors.pink.shade50),
          inputCard("間隔", "📏", stepController, Colors.orange.shade50,
              minus: false),

          SwitchListTile(
            title: Text(soundOn ? "🔊 ON" : "🔇 OFF"),
            value: soundOn,
            onChanged: (v) {
              setState(() => soundOn = v);
              saveSettings();
            },
          ),

          const SizedBox(height: 20),

          Text("結果",
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

          Text(result?.toString() ?? "？",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: size)),

          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: generate,
            child: const Text("🎰 ルーレットをまわす"),
          ),

          const SizedBox(height: 20),

          Wrap(
            spacing: 8,
            children: history
                .map((e) => Chip(label: Text(e.toString())))
                .toList(),
          ),
        ],
      ),
    );
  }
}