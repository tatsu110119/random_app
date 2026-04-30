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
  bool resultGlow = false;

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
    setState(() {
      history.clear();
    });
  }

  double smoothStep(double x) {
    return x * x * (3 - 2 * x);
  }

  double lerp(double a, double b, double t) {
    return a + (b - a) * t;
  }

  int rouletteDelay(int elapsedMs) {
    const total = 13000;
    final p = elapsedMs / total;

    if (p < 0.42) {
      final t = smoothStep(p / 0.42);
      return lerp(650, 70, t).toInt();
    } else if (p < 0.62) {
      return 38;
    } else {
      final t = smoothStep((p - 0.62) / 0.38);
      return lerp(55, 780, t).toInt();
    }
  }

  Future<void> prepareFinishSound() async {
    if (!soundOn) return;

    try {
      await finishPlayer.setReleaseMode(ReleaseMode.stop);
      await finishPlayer.setVolume(0.01);
      await finishPlayer.play(AssetSource('sounds/finish.mp3'));
      await Future.delayed(const Duration(milliseconds: 80));
      await finishPlayer.stop();
      await finishPlayer.setVolume(1.0);
    } catch (_) {}
  }

  Future<void> playFinishSound() async {
    if (!soundOn) return;

    try {
      await finishPlayer.stop();
      await finishPlayer.setVolume(1.0);
      await finishPlayer.play(AssetSource('sounds/finish.mp3'));
    } catch (_) {}
  }

  Future<void> generate() async {
    if (isRolling) return;

    final min = int.tryParse(minController.text);
    final max = int.tryParse(maxController.text);
    final step = int.tryParse(stepController.text);

    if (min == null || max == null || step == null) {
      showError("すべて整数で入力してください");
      return;
    }

    if (step <= 0) {
      showError("間隔は1以上にしてください");
      return;
    }

    if (min > max) {
      showError("最小値は最大値以下にしてください");
      return;
    }

    final list = <int>[];
    for (int i = min; i <= max; i += step) {
      list.add(i);
    }

    if (list.isEmpty) {
      showError("候補がありません");
      return;
    }

    setState(() {
      isRolling = true;
      hasFinalResult = false;
      resultGlow = false;
    });

    if (soundOn) {
      try {
        await rollingPlayer.setReleaseMode(ReleaseMode.loop);
        await rollingPlayer.play(AssetSource('sounds/rolling.mp3'));
      } catch (_) {}

      await prepareFinishSound();
    }

    final stopwatch = Stopwatch()..start();

    while (stopwatch.elapsedMilliseconds < 13000) {
      final delay = rouletteDelay(stopwatch.elapsedMilliseconds);

      setState(() {
        result = list[random.nextInt(list.length)];
      });

      await Future.delayed(Duration(milliseconds: delay));
    }

    try {
      await rollingPlayer.stop();
    } catch (_) {}

    final finalValue = list[random.nextInt(list.length)];

    setState(() {
      result = finalValue;
      history.insert(0, finalValue);
      isRolling = false;
      hasFinalResult = true;
      resultGlow = true;
    });

    await playFinishSound();

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() {
          resultGlow = false;
        });
      }
    });

    await saveHistory();
  }

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void makeNegative(TextEditingController controller) {
    final text = controller.text.trim();
    setState(() {
      if (text.isEmpty || text == "0") {
        controller.text = "-1";
      } else if (!text.startsWith("-")) {
        controller.text = "-$text";
      }
    });
  }

  void makePositive(TextEditingController controller) {
    final text = controller.text.trim();
    setState(() {
      controller.text = text.replaceFirst("-", "");
    });
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

  Widget numberCard({
    required String title,
    required String emoji,
    required TextEditingController controller,
    required Color backgroundColor,
    required Color accentColor,
    required bool allowMinus,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$emoji $title',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              hintText: '数字を入力',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          if (allowMinus) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed:
                        isRolling ? null : () => makeNegative(controller),
                    style: FilledButton.styleFrom(
                      backgroundColor: accentColor,
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text('マイナスにする'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        isRolling ? null : () => makePositive(controller),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      side: BorderSide(color: accentColor, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: Text(
                      'プラスにする',
                      style: TextStyle(color: accentColor),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = hasFinalResult ? 96.0 : 54.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('🎀 乱数ルーレット 🎀'),
        centerTitle: true,
        backgroundColor: const Color(0xFFFFD6EA),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Text(
              '例：-20〜20、間隔5',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF8A5A70),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            numberCard(
              title: '最小値',
              emoji: '⬇️',
              controller: minController,
              backgroundColor: const Color(0xFFE3F2FD),
              accentColor: const Color(0xFF1976D2),
              allowMinus: true,
            ),
            numberCard(
              title: '最大値',
              emoji: '⬆️',
              controller: maxController,
              backgroundColor: const Color(0xFFFFE4F2),
              accentColor: const Color(0xFFD81B60),
              allowMinus: true,
            ),
            numberCard(
              title: '間隔',
              emoji: '📏',
              controller: stepController,
              backgroundColor: const Color(0xFFFFF3E0),
              accentColor: const Color(0xFFF57C00),
              allowMinus: false,
            ),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: SwitchListTile(
                title: Text(soundOn ? '🔊 効果音 ON' : '🔇 効果音 OFF'),
                value: soundOn,
                onChanged: isRolling
                    ? null
                    : (value) {
                        setState(() {
                          soundOn = value;
                        });
                        saveSettings();
                      },
              ),
            ),
            const SizedBox(height: 24),
            AnimatedScale(
              scale: isRolling ? 1.04 : hasFinalResult ? 1.16 : 1.0,
              duration: const Duration(milliseconds: 250),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 34),
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
                      color: resultGlow
                          ? Colors.pinkAccent.withOpacity(0.75)
                          : Colors.pinkAccent.withOpacity(0.25),
                      blurRadius: resultGlow ? 48 : 24,
                      spreadRadius: resultGlow ? 10 : 0,
                      offset: const Offset(0, 10),
                    ),
                    if (resultGlow)
                      BoxShadow(
                        color: Colors.yellowAccent.withOpacity(0.75),
                        blurRadius: 36,
                        spreadRadius: 8,
                      ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      '結果',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF7A2450),
                      ),
                    ),
                    AnimatedDefaultTextStyle(
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
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(34),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFF5FA2),
                    Color(0xFFFF9ACB),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.pinkAccent.withOpacity(0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: FilledButton.icon(
                onPressed: isRolling ? null : generate,
                icon: const Icon(Icons.casino),
                label: Text(isRolling ? 'くるくる中…' : '🎰 ルーレットをまわす'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  minimumSize: const Size(double.infinity, 64),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(34),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 26),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '📜 履歴',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF7A2450),
                  ),
                ),
                TextButton.icon(
                  onPressed:
                      history.isEmpty || isRolling ? null : clearHistory,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('消去'),
                ),
              ],
            ),
            if (history.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text("まだ履歴はありません 🐣")),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: history.map((value) {
                  return Chip(
                    label: Text(
                      value.toString(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: const Color(0xFFFFE4F2),
                    side: const BorderSide(color: Color(0xFFFFB8DA)),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}