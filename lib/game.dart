import 'package:flutter/services.dart' show rootBundle;
import 'package:hive/hive.dart';
import 'dart:math';

import 'package:word_flower/played_game.dart';
import 'package:word_flower/rng.dart';

class Game {
  final List<String> extraLetters;
  final String centerLetter;
  final List<String> validWords;
  final List<String> commonWords;
  final PlayedGame playedGame;
  final int seed;
  bool isReviewed = false;
  final bool isPractice;

  List<String> lettersToShow = [];
  final List<String> obtainedWords = [];

  List<String>? _alphaObtainedWords;

  Game({
    required this.extraLetters,
    required this.centerLetter,
    required this.validWords,
    required this.commonWords,
    required this.playedGame,
    required this.isPractice,
    required this.seed,
  });

  /// Marks the game as reviewed
  void setAsReviewed() {
    if (!playedGame.reviewed && playedGame.isInBox) {
      playedGame.reviewed = true;
      playedGame.save();
    }
    isReviewed = true;
  }

  List<String> get alphaObtainedWords {
    _alphaObtainedWords ??= [...obtainedWords]..sort();
    return _alphaObtainedWords!;
  }

  int get score => obtainedWords.fold(0, (sum, word) => sum + word.length);

  int get possibleScore => commonWords.fold(0, (sum, word) => sum + word.length);

  /// Shuffles the letters to display
  void shuffleAndSetLetters() {
    final random = Random();
    lettersToShow = [...extraLetters]..shuffle(random);
  }

  /// Checks if the given letters form a valid word
  bool checkLetters(String letters) {
    if (!letters.contains(centerLetter)) return false;
    if (validWords.contains(letters) && !obtainedWords.contains(letters)) {
      obtainedWords.add(letters);
      playedGame.obtainedWords = obtainedWords;
      playedGame.save();
      _alphaObtainedWords = null;
      return true;
    }
    return false;
  }

  /// Creates a new game instance
  static Future<Game> createGame(int seed, Box<PlayedGame>? box, bool isPractice) async {
    final largeDictionaryFuture = StoredDictionary.load('assets/uncommon-long-words.txt');
    final commonDictionary = await StoredDictionary.load('assets/common-long-words.txt');
    final veryCommonDictionary = await StoredDictionary.load('assets/very-common-long-words.txt');

    if (box?.isNotEmpty ?? false) {
      final existingGame = _getExistingGame(seed, isPractice, box!);
      if (existingGame != null) {
        return _buildGameFromExisting(existingGame, largeDictionaryFuture, commonDictionary);
      }
    }

    return _createNewGame(seed, largeDictionaryFuture, commonDictionary, veryCommonDictionary, box, isPractice);
  }

  static PlayedGame? _getExistingGame(int seed, bool isPractice, Box<PlayedGame> box) {
    const practiceGameKey = 101;
    return isPractice ? box.get(practiceGameKey) : box.get(seed);
  }

  static Future<Game> _buildGameFromExisting(
    PlayedGame existingGame,
    Future<StoredDictionary> largeDictionaryFuture,
    StoredDictionary commonDictionary,
  ) async {
    final largeDictionary = await largeDictionaryFuture;
    final commonWords = _getMatchingWords(commonDictionary.words, existingGame.extraLetters, existingGame.centerLetter);
    final validWords = _getMatchingWords(largeDictionary.words, existingGame.extraLetters, existingGame.centerLetter);

    final allWords = {...validWords, ...commonWords};
    final game = Game(
      extraLetters: existingGame.extraLetters,
      centerLetter: existingGame.centerLetter,
      validWords: allWords.toList(),
      commonWords: commonWords,
      playedGame: existingGame,
      isPractice: false,
      seed: existingGame.seed,
    );
    game.obtainedWords.addAll(existingGame.obtainedWords);
    game.shuffleAndSetLetters();
    game.isReviewed = existingGame.reviewed;

    return game;
  }

  static Future<Game> _createNewGame(
    int seed,
    Future<StoredDictionary> largeDictionaryFuture,
    StoredDictionary commonDictionary,
    StoredDictionary veryCommonDictionary,
    Box<PlayedGame>? box,
    bool isPractice,
  ) async {
    final random = LinearCongruentialGenerator(seed);
    final letters = List.generate(26, (i) => String.fromCharCode('a'.codeUnitAt(0) + i));
    const vowels = ['a', 'e', 'i', 'o', 'u'];

    String centerLetter;
    List<String> otherLetters;
    List<String> includedCommonWords;

    do {
      centerLetter = _randomLetter(random, letters);
      otherLetters = _generateOtherLetters(random, letters, vowels, centerLetter);
      includedCommonWords = _getMatchingWords(commonDictionary.words, otherLetters, centerLetter);
    } while (!_isValidLetterSet(includedCommonWords, otherLetters, centerLetter, veryCommonDictionary));

    final largeDictionary = await largeDictionaryFuture;
    final validWords = {..._getMatchingWords(largeDictionary.words, otherLetters, centerLetter), ...includedCommonWords};

    final playedGame = PlayedGame(
      seed: seed,
      reviewed: false,
      obtainedWords: [],
      centerLetter: centerLetter,
      extraLetters: otherLetters,
      datePlayed: DateTime.now().toUtc(),
    );
    box?.put(isPractice ? 101 : seed, playedGame);

    final game = Game(
      extraLetters: otherLetters,
      centerLetter: centerLetter,
      validWords: validWords.toList(),
      commonWords: includedCommonWords,
      playedGame: playedGame,
      isPractice: isPractice,
      seed: seed,
    );
    game.shuffleAndSetLetters();

    return game;
  }

  static String _randomLetter(LinearCongruentialGenerator random, List<String> letters) =>
      letters[(random.nextDouble() * 25).round()];

  static List<String> _generateOtherLetters(LinearCongruentialGenerator random, List<String> letters, List<String> vowels, String centerLetter) {
    final otherLetters = <String>[];
    if (!vowels.contains(centerLetter)) {
      otherLetters.add(vowels[(random.nextDouble() * (vowels.length - 1)).round()]);
    }

    while (otherLetters.length < 6) {
      final letter = letters[(random.nextDouble() * 25).round()];
      if (letter != centerLetter && !otherLetters.contains(letter)) {
        otherLetters.add(letter);
      }
    }

    return otherLetters;
  }

  static bool _isValidLetterSet(
    List<String> includedCommonWords,
    List<String> otherLetters,
    String centerLetter,
    StoredDictionary veryCommonDictionary,
  ) {
    final veryCommonWordCount = _getMatchingWords(veryCommonDictionary.words, otherLetters, centerLetter).length;
    return veryCommonWordCount >= 10 &&
        includedCommonWords.length >= 25 &&
        includedCommonWords.any((word) => word.contains(centerLetter) && otherLetters.every(word.contains));
  }

  static List<String> _getMatchingWords(List<String> wordList, List<String> extraLetters, String centerLetter) {
    centerLetter = centerLetter.toLowerCase();
    extraLetters = extraLetters.map((e) => e.toLowerCase()).toList();
    return wordList
        .map((word) => word.toLowerCase())
        .where((word) => word.contains(centerLetter) && word.split('').every((char) => char == centerLetter || extraLetters.contains(char)))
        .toList();
  }
}

class StoredDictionary {
  final List<String> words;

  StoredDictionary(String data) : words = data.split('\n').map((line) => line.trim()).toList();

  static Future<StoredDictionary> load(String filename) async {
    final data = await rootBundle.loadString(filename);
    return StoredDictionary(data);
  }
}
