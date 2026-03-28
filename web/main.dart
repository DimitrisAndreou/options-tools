import 'dart:js_interop';

import 'package:options_tools/js_interop_bindings.dart';

@JS()
// Defined in main.js
external void jsMain();

void main() {
  setupJsInterop();
  jsMain();
}
