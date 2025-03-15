// ignore_for_file: non_constant_identifier_names

extension DateTimeAsExpirationExtension on DateTime {
  int get DTE => _remainingTime.inDays;
  int get HTE => _remainingTime.inHours;

  Duration get _remainingTime => difference(DateTime.now());
}

extension IntAsExpirationOperations on int {
  DateTime get DTE => DateTime.now().add(Duration(days: this));
  DateTime get HTE => DateTime.now().add(Duration(hours: this));
}
