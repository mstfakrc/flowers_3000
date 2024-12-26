import 'package:flutter/material.dart';
import 'package:word_flower/game_state_manager.dart';
import 'package:word_flower/main_game_page.dart';

void main() => runApp(const FlowersApp());

class FlowersApp extends StatelessWidget {
  const FlowersApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeNotifier = ValueNotifier(ThemeMode.light);
    final gameStateManager = GameStateManager(themeNotifier: themeNotifier);

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) => MaterialApp(
        title: 'Flowers 3000',
        debugShowCheckedModeBanner: false, // Debug yazısını kaldırır
        themeMode: currentMode,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.green,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.green,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: MainGamePage(
          title: 'Flowers 3000',
          themeNotifier: themeNotifier,
          gameStateManager: gameStateManager,
        ),
      ),
    );
  }
}
