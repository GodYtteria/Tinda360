String timeOfDayGreeting(DateTime now, {required bool isFilipino}) {
  final hour = now.hour;
  if (hour >= 5 && hour < 12) {
    return isFilipino ? 'Magandang umaga!' : 'Good morning!';
  }
  if (hour >= 12 && hour < 14) {
    return isFilipino ? 'Magandang tanghali!' : 'Good noon!';
  }
  if (hour >= 14 && hour < 18) {
    return isFilipino ? 'Magandang hapon!' : 'Good afternoon!';
  }
  return isFilipino ? 'Magandang gabi!' : 'Good evening!';
}
