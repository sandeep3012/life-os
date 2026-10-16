/// A hybrid logical clock stamp: wall-clock milliseconds, a counter for
/// changes within the same millisecond (or while this phone's clock is
/// behind one it has heard from), and the device that wrote it.
///
/// Stamps compare as plain strings — the server does exactly that to decide
/// which of two edits to keep — so every field is fixed-width.
class Hlc implements Comparable<Hlc> {
  const Hlc(this.millis, this.counter, this.deviceId);

  final int millis;
  final int counter;
  final String deviceId;

  /// Older than any real edit: what a row queued when sync was switched on
  /// carries, so the copy already on the server wins over it.
  factory Hlc.seed(String deviceId) => Hlc(0, 0, deviceId);

  static Hlc parse(String value) {
    final parts = value.split('-');
    return Hlc(
      int.parse(parts[0]),
      int.parse(parts[1], radix: 16),
      parts.sublist(2).join('-'),
    );
  }

  /// The stamp for a local change made at [wallMillis], given the latest
  /// stamp this phone has issued or seen. Never goes backwards, even if the
  /// phone's clock does.
  static Hlc next(Hlc? latest, int wallMillis, String deviceId) {
    if (latest == null || wallMillis > latest.millis) {
      return Hlc(wallMillis, 0, deviceId);
    }
    return Hlc(latest.millis, latest.counter + 1, deviceId);
  }

  /// The later of the two, for remembering what's been seen.
  static Hlc? latestOf(Hlc? a, Hlc? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.compareTo(b) >= 0 ? a : b;
  }

  @override
  String toString() =>
      '${millis.toString().padLeft(15, '0')}-'
      '${counter.toRadixString(16).padLeft(5, '0')}-$deviceId';

  @override
  int compareTo(Hlc other) => toString().compareTo(other.toString());

  @override
  bool operator ==(Object other) => other is Hlc && '$other' == '$this';

  @override
  int get hashCode => toString().hashCode;
}
