import 'dart:js_interop';

import 'package:options_tools/js_interop_bindings.dart';

@JS()
// Defined in yf_main.js
external void jsYfMain();

void main() {
  setupJsInterop();
  jsYfMain();
}
