import 'package:flutter/material.dart';

/// Provider to manage voice assistant state across admin pages
class VoiceAssistantProvider extends ChangeNotifier {
  // UI State
  bool _showOverlay = false;
  bool _showLanguageSelection = false;
  bool _hasSelectedLanguage = false;
  bool _hasGreeted = false;
  String _language = 'fr-FR';
  String _assistantState = 'idle'; // idle, listening, thinking, speaking, success, error

  // Transcript state
  String _finalTranscript = '';
  String _interimTranscript = '';
  String _transcript = '';

  // Response state
  Map<String, dynamic>? _response;
  bool _usedLocalFallback = false;
  String _status = 'Done';
  bool _isListening = false;
  bool _isThinking = false;
  bool _isSpeaking = false;

  // Getters
  bool get showOverlay => _showOverlay;
  bool get showLanguageSelection => _showLanguageSelection;
  bool get hasSelectedLanguage => _hasSelectedLanguage;
  bool get hasGreeted => _hasGreeted;
  String get language => _language;
  String get assistantState => _assistantState;
  String get finalTranscript => _finalTranscript;
  String get interimTranscript => _interimTranscript;
  String get transcript => _transcript;
  Map<String, dynamic>? get response => _response;
  bool get usedLocalFallback => _usedLocalFallback;
  String get status => _status;
  bool get isListening => _isListening;
  bool get isThinking => _isThinking;
  bool get isSpeaking => _isSpeaking;

  // Setters
  void setShowOverlay(bool value) {
    _showOverlay = value;
    notifyListeners();
  }

  void setShowLanguageSelection(bool value) {
    _showLanguageSelection = value;
    notifyListeners();
  }

  void setHasSelectedLanguage(bool value) {
    _hasSelectedLanguage = value;
    notifyListeners();
  }

  void setHasGreeted(bool value) {
    _hasGreeted = value;
    notifyListeners();
  }

  void setLanguage(String lang) {
    _language = lang;
    notifyListeners();
  }

  void setAssistantState(String state) {
    _assistantState = state;
    notifyListeners();
  }

  void setFinalTranscript(String text) {
    _finalTranscript = text;
    notifyListeners();
  }

  void setInterimTranscript(String text) {
    _interimTranscript = text;
    notifyListeners();
  }

  void setTranscript(String text) {
    _transcript = text;
    notifyListeners();
  }

  void setResponse(Map<String, dynamic>? data) {
    _response = data;
    notifyListeners();
  }

  void setUsedLocalFallback(bool value) {
    _usedLocalFallback = value;
    notifyListeners();
  }

  void setStatus(String status) {
    _status = status;
    notifyListeners();
  }

  void setIsListening(bool value) {
    _isListening = value;
    notifyListeners();
  }

  void setIsThinking(bool value) {
    _isThinking = value;
    notifyListeners();
  }

  void setIsSpeaking(bool value) {
    _isSpeaking = value;
    notifyListeners();
  }

  /// Clear transcripts after processing (called after each interaction)
  void clearTranscripts() {
    _finalTranscript = '';
    _interimTranscript = '';
    _transcript = '';
    notifyListeners();
  }

  /// Reset state when closing overlay
  void resetState() {
    _showOverlay = false;
    _showLanguageSelection = false;
    _isListening = false;
    _isThinking = false;
    _assistantState = 'idle';
    _status = 'Done';
    _response = null;
    clearTranscripts();
    notifyListeners();
  }
}
