double annualizedYield(double yield, Duration duration) =>
    1.0 + (yield - 1.0) * Duration(days: 365).inMinutes / duration.inMinutes;
