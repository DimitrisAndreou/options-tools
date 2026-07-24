import 'dart:js_interop';
import 'package:options_tools/data/ibkr.dart';

@JS()
external void jsMainIbkr();

@JS()
external set parseIbkrXmlDart(JSFunction value);

void main() {
  parseIbkrXmlDart = (JSString xmlText) {
    return parseIbkrXml(xmlText.toDart).toJS;
  }.toJS;
  jsMainIbkr();
}
