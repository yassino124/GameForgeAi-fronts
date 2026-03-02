@JS()
library;

import 'package:js/js.dart';

@JS('SpeechRecognition')
@staticInterop
class JsSpeechRecognition {
	external factory JsSpeechRecognition();
}

extension JsSpeechRecognitionExtension on JsSpeechRecognition {
	external set continuous(bool value);
	external set interimResults(bool value);
	external set lang(String value);
	external void start();
	external void stop();
	external set onresult(Function callback);
	external set onerror(Function callback);
	external set onend(Function callback);
}

@JS('webkitSpeechRecognition')
@staticInterop
class JsWebkitSpeechRecognition {
	external factory JsWebkitSpeechRecognition();
}

extension JsWebkitSpeechRecognitionExtension on JsWebkitSpeechRecognition {
	external set continuous(bool value);
	external set interimResults(bool value);
	external set lang(String value);
	external void start();
	external void stop();
	external set onresult(Function callback);
	external set onerror(Function callback);
	external set onend(Function callback);
}
