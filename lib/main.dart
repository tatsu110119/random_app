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

    // 🔊 回転音
    if (soundOn) {
      await rollingPlayer.setReleaseMode(ReleaseMode.loop);
      await rollingPlayer.play(AssetSource('sounds/rolling.mp3'));

      // Web対策：先に1回鳴らしておく
      await finishPlayer.play(AssetSource('sounds/finish.mp3'));
      await finishPlayer.stop();
    }

    final stopwatch = Stopwatch()..start();

    while (stopwatch.elapsedMilliseconds < 13000) {
      final t = stopwatch.elapsedMilliseconds;

      int delay;
      if (t < 5000) {
        delay = 350;
      } else if (t < 8000) {
        delay = 45;
      } else {
        final r = (t - 8000) / 5000;
        delay = (60 + 450 * r).toInt();
      }

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

    // 🔊 フィニッシュ音
    if (soundOn) {
      await finishPlayer.stop();
      await finishPlayer.play(AssetSource('sounds/finish.mp3'));
    }

    await saveHistory();
  }

  void showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  void makeNegative(TextEditingController c) {
    final t = c.text;
    if (!t.startsWith('-')) {
      c.text = '-$t';
    }
  }

  void makePositive(TextEditingController c) {
    c.text = c.text.replaceFirst('-', '');
  }

  Widget numberInput(String label, TextEditingController c, bool minus) {
    return Column(
      children: [
        TextField(
          controller: c,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        if (minus)
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => makeNegative(c),
                  child: const Text('−'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => makePositive(c),
                  child: const Text('＋'),
                ),
              ),
            ],
          ),
      ],
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
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            numberInput("最小値", minController, true),
            const SizedBox(height: 12),
            numberInput("最大値", maxController, true),
            const SizedBox(height: 12),
            numberInput("間隔", stepController, false),

            const SizedBox(height: 20),

            SwitchListTile(
              title: const Text("効果音"),
              value: soundOn,
              onChanged: (v) {
                setState(() => soundOn = v);
                saveSettings();
              },
            ),

            const SizedBox(height: 10),

            Text(
              result?.toString() ?? "？",
              style: TextStyle(fontSize: size),
            ),

            const SizedBox(height: 10),

            ElevatedButton(
              onPressed: generate,
              child: const Text("まわす"),
            ),

            const SizedBox(height: 10),

            ElevatedButton(
              onPressed: clearHistory,
              child: const Text("履歴削除"),
            ),
          ],
        ),
      ),
    );
  }
}