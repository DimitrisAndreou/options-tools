// ignore_for_file: non_constant_identifier_names

extension DateTimeAsExpirationExtension on DateTime {
  int get daysLeft => _remainingTime.inDays;
  int get hoursLeft => _remainingTime.inHours;
  int get minutesLeft => _remainingTime.inMinutes;
  int get hoursModuloDaysLeft => hoursLeft - daysLeft * 24;

  Duration get _remainingTime => difference(DateTime.now());

  // Neutral yield is 1.0, neutral rate is 0.0
  double rateToAnnualRate(double rate) =>
      rate * Duration(days: 365).inMinutes / _remainingTime.inMinutes;
  double annualRateToRate(double annualRate) =>
      (_remainingTime.inMinutes * annualRate) / Duration(days: 365).inMinutes;

  String get formattedDate {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '$day ${months[month - 1]} $year';
  }
}

extension IntAsExpirationOperations on int {
  DateTime get DTE => DateTime.now().add(Duration(days: this));
  DateTime get HTE => DateTime.now().add(Duration(hours: this));
}

double yieldToRate(double yield) => yield - 1.0;
double rateToYield(double rate) => rate + 1.0;
