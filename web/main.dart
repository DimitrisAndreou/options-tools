import 'dart:js_interop';

import 'package:options_tools/strategies_gateway.dart';

@JS()
// Defined in deribit_main.js
external void jsMain();

void main() {
  setupJsInterop();
  jsMain();
}
