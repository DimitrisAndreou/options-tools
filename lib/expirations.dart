// ignore_for_file: non_constant_identifier_names

extension DateTimeAsExpirationExtension on DateTime {
  int get daysLeft => _remainingTime.inDays;
  int get hoursLeft => _remainingTime.inHours;
  int get minutesLeft => _remainingTime.inMinutes;
  int get hoursModuloDaysLeft => hoursLeft - daysLeft * 24;

  Duration get _remainingTime => difference(DateTime.now());
}

extension IntAsExpirationOperations on int {
  DateTime get DTE => DateTime.now().add(Duration(days: this));
  DateTime get HTE => DateTime.now().add(Duration(hours: this));
}

// TODO: move to extensions above
double annualizedYield(double yield, Duration duration) =>
    1.0 + (yield - 1.0) * Duration(days: 365).inMinutes / duration.inMinutes;
