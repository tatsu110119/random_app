import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';

void main() {
  runApp(const MyApp());
}

enum RouletteSpeed {
  short,
  normal,
  long,
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

  RouletteSpeed speed = RouletteSpeed.normal;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedHistory = prefs.getStringList('history') ?? [];
    final savedSound = prefs.getBool('soundOn') ?? true;
    final savedSpeed = prefs.getString('speed') ?? 'normal';

    setState(() {
      history = savedHistory.map(int.parse).toList();
      soundOn = savedSound;

      if (savedSpeed == 'short') {
        speed = RouletteSpeed.short;
      } else if (savedSpeed == 'long') {
        speed = RouletteSpeed.long;
      } else {
        speed = RouletteSpeed.normal;
      }
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
    await prefs.setString('speed', speed.name);
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('history');

    setState(() {
      history.clear();
    });
  }

  int totalTimeMs() {
    switch (speed) {
      case RouletteSpeed.short:
        return 6000;
      case RouletteSpeed.normal:
        return 13000;
      case RouletteSpeed.long:
        return 20000;
    }
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
    });

    if (soundOn) {
      await rollingPlayer.setReleaseMode(ReleaseMode.loop);
      await rollingPlayer.play(AssetSource('sounds/rolling.mp3'));
    }

    final total = totalTimeMs();
    final stopwatch = Stopwatch()..start();

    while (stopwatch.elapsedMilliseconds < total) {
      final elapsed = stopwatch.elapsedMilliseconds;
      final rate = elapsed / total;

      int delay;

      if (rate < 0.38) {
        delay = 350;
      } else if (rate < 0.62) {
        delay = 45;
      } else {
        final t = (rate - 0.62) / 0.38;
        delay = (60 + 450 * t).toInt();
      }

      setState(() {
        result = list[random.nextInt(list.length)];
      });

      await Future.delayed(Duration(milliseconds: delay));
    }

    stopwatch.stop();

    if (soundOn) {
      await rollingPlayer.stop();
    }

    final finalValue = list[random.nextInt(list.length)];

    setState(() {
      result = finalValue;
      history.insert(0, finalValue);
      isRolling = false;
      hasFinalResult = true;
    });

    if (soundOn) {
      await finishPlayer.play(AssetSource('sounds/finish.mp3'));
    }

    await saveHistory();
  }

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void addMinus(TextEditingController controller) {
    final text = controller.text;

    setState(() {
      if (text.startsWith('-')) {
        controller.text = text.substring(1);
      } else {
        controller.text = '-$text';
      }
    });
  }

  void addValue(TextEditingController controller, int amount) {
    final value = int.tryParse(controller.text) ?? 0;
    setState(() {
      controller.text = (value + amount).toString();
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

  Widget numberInput({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required bool allowMinus,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          decoration: cuteInput(label, icon),
          keyboardType: TextInputType.numberWithOptions(
            signed: allowMinus,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (allowMinus)
              Expanded(
                child: OutlinedButton(
                  onPressed: isRolling ? null : () => addMinus(controller),
                  child: const Text('±'),
                ),
              ),
            if (allowMinus) const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: isRolling ? null : () => addValue(controller, -1),
                child: const Text('-1'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: isRolling ? null : () => addValue(controller, 1),
                child: const Text('+1'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String speedLabel(RouletteSpeed value) {
    switch (value) {
      case RouletteSpeed.short:
        return '短い';
      case RouletteSpeed.normal:
        return '普通';
      case RouletteSpeed.long:
        return '長い';
    }
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
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEAF4),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Column(
                        children: [
                          numberInput(
                            label: '最小値',
                            controller: minController,
                            icon: Icons.remove_circle_outline,
                            allowMinus: true,
                          ),
                          const SizedBox(height: 16),
                          numberInput(
                            label: '最大値',
                            controller: maxController,
                            icon: Icons.add_circle_outline,
                            allowMinus: true,
                          ),
                          const SizedBox(height: 16),
                          numberInput(
                            label: '間隔',
                            controller: stepController,
                            icon: Icons.straighten,
                            allowMinus: false,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        children: [
                          SwitchListTile(
                            title: const Text('効果音'),
                            subtitle: Text(soundOn ? 'ON' : 'OFF'),
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
                          const Divider(),
                          Row(
                            children: [
                              const Text(
                                '時間',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SegmentedButton<RouletteSpeed>(
                                  segments: const [
                                    ButtonSegment(
                                      value: RouletteSpeed.short,
                                      label: Text('短い'),
                                    ),
                                    ButtonSegment(
                                      value: RouletteSpeed.normal,
                                      label: Text('普通'),
                                    ),
                                    ButtonSegment(
                                      value: RouletteSpeed.long,
                                      label: Text('長い'),
                                    ),
                                  ],
                                  selected: {speed},
                                  onSelectionChanged: isRolling
                                      ? null
                                      : (value) {
                                          setState(() {
                                            speed = value.first;
                                          });
                                          saveSettings();
                                        },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    AnimatedScale(
                      scale: isRolling ? 1.05 : hasFinalResult ? 1.2 : 1.0,
                      duration: const Duration(milliseconds: 250),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 38),
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
                        minimumSize: const Size(double.infinity, 60),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

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
                          onPressed: history.isEmpty || isRolling
                              ? null
                              : clearHistory,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('消去'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    if (history.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text("まだ履歴はありません 🐣"),
                        ),
                      )
                    else
                      ...history.asMap().entries.map((entry) {
                        final index = entry.key;
                        final value = entry.value;

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
                              value.toString(),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}