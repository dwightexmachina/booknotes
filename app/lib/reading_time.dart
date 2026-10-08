/// Assumed reading/speaking rate used to approximate how long a body of
/// notes would take to read aloud. Change this one value to retune every
/// "Time Approximation" display in the app.
const int wordsPerMinute = 180;

/// Formats a word count as an approximate duration at [wordsPerMinute].
String formatReadingTime(int wordCount) {
  final minutes = (wordCount / wordsPerMinute).round();
  if (minutes < 1) return '<1 min';
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  return remainder == 0 ? '${hours}h' : '${hours}h ${remainder}m';
}
