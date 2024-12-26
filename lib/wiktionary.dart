import 'dart:convert';
import 'package:async/async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class DefinitionLookupState extends ChangeNotifier {
  String? word;
  bool isLoading = false;
  String? definition;
  CancelableOperation<String>? _operation;

  bool get isRunning => _operation != null && !_operation!.isCanceled && !_operation!.isCompleted;

  @override
  void dispose() {
    _cancelOperation();
    super.dispose();
  }

  void loadDefinition(String word) {
    this.word = word;
    _startLoading();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchDefinition());
  }

  Future<void> _fetchDefinition() async {
    if (word == null) {
      _stopLoading();
      return;
    }

    if (kIsWeb) {
      await _openInNewTab(_getWebUrl(word!));
      return;
    }

    _cancelOperation();
    _operation = CancelableOperation.fromFuture(_fetchDefinitionFromApi(word!));

    try {
      definition = await _operation!.value;
    } catch (_) {
      definition = 'Error fetching definition.';
    } finally {
      _stopLoading();
    }
  }

  Future<void> _openInNewTab(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      final launched = await launchUrl(uri, webOnlyWindowName: '_blank');
      if (!launched) {
        debugPrint('Problem launching URL: $url');
      }
    }
    dismissDefinition();
  }

  Future<String> _fetchDefinitionFromApi(String word) async {
    final url = Uri.parse(_getApiUrl(word));
    final response = await http.get(url);

    if (response.statusCode == 200) {
      return _extractDefinitionFromResponse(response.body) ?? 'No definition found.';
    }
    return 'Error fetching definition.';
  }

  String? _extractDefinitionFromResponse(String responseBody) {
    final data = json.decode(responseBody);
    final pages = data['query']['pages'];
    final page = pages.first;
    return page.containsKey('extract') && page['extract'].isNotEmpty ? page['extract'] : null;
  }

  void dismissDefinition() {
    _cancelOperation();
    _resetState();
  }

  void _startLoading() {
    isLoading = true;
    notifyListeners();
  }

  void _stopLoading() {
    isLoading = false;
    notifyListeners();
  }

  void _cancelOperation() {
    if (isRunning) {
      _operation?.cancel();
    }
    _operation = null;
  }

  void _resetState() {
    word = null;
    definition = null;
    _stopLoading();
  }

  static String _getApiUrl(String word) =>
      'https://en.wiktionary.org/w/api.php?action=query&format=json&prop=extracts&titles=$word&formatversion=latest&exchars=1000&explaintext=1';

  static String _getWebUrl(String word) => 'https://en.m.wiktionary.org/wiki/$word';

  @override
  String toString() {
    if (word == null) return '';
    if (isLoading) return '\n\n$word - loading..\n\n';
    return definition != null ? '$word\n\n$definition' : word!;
  }
}
