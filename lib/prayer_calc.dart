import 'dart:math' as math;

/// Lima waktu sholat wajib.
enum Prayer { subuh, dzuhur, ashar, maghrib, isya }

extension PrayerLabel on Prayer {
  String get label => const ['Subuh', 'Dzuhur', 'Ashar', 'Maghrib', 'Isya'][index];
}

class PrayerTimes {
  final DateTime date;
  final DateTime sunrise;
  final Map<Prayer, DateTime> times;

  const PrayerTimes(this.date, this.sunrise, this.times);

  DateTime operator [](Prayer p) => times[p]!;
}

/// Perhitungan waktu sholat offline, parameter mengikuti Kemenag RI:
/// Subuh 20°, Isya 18°, Ashar madzhab Syafi'i, ihtiyat 2 menit.
class PrayerCalculator {
  static const double fajrAngle = 20.0;
  static const double ishaAngle = 18.0;
  static const int ihtiyatMinutes = 2;

  static double _d2r(double d) => d * math.pi / 180.0;
  static double _r2d(double r) => r * 180.0 / math.pi;
  static double _fix(double a, double b) {
    final r = a % b;
    return r < 0 ? r + b : r;
  }

  static PrayerTimes calculate(DateTime date, double lat, double lng) {
    final day = DateTime(date.year, date.month, date.day);
    final tz = day.add(const Duration(hours: 12)).timeZoneOffset.inMinutes / 60.0;

    // Julian date sekitar tengah hari lokal.
    final jd = DateTime.utc(day.year, day.month, day.day).millisecondsSinceEpoch / 86400000.0 +
        2440587.5 -
        lng / 360.0 +
        0.5;

    // Posisi matahari (deklinasi & equation of time).
    final d = jd - 2451545.0;
    final g = _fix(357.529 + 0.98560028 * d, 360);
    final q = _fix(280.459 + 0.98564736 * d, 360);
    final l = _fix(q + 1.915 * math.sin(_d2r(g)) + 0.020 * math.sin(_d2r(2 * g)), 360);
    final e = 23.439 - 0.00000036 * d;
    final ra = _fix(_r2d(math.atan2(math.cos(_d2r(e)) * math.sin(_d2r(l)), math.cos(_d2r(l)))) / 15, 24);
    final decl = _r2d(math.asin(math.sin(_d2r(e)) * math.sin(_d2r(l))));
    final eqt = _fix(q / 15 - ra + 12, 24) - 12;

    final dhuhr = 12 + tz - lng / 15 - eqt;

    // Selisih jam dari dzuhur saat matahari berada `angle` derajat di bawah ufuk.
    double hourAngle(double angle) {
      final x = (-math.sin(_d2r(angle)) - math.sin(_d2r(lat)) * math.sin(_d2r(decl))) /
          (math.cos(_d2r(lat)) * math.cos(_d2r(decl)));
      return _r2d(math.acos(x.clamp(-1.0, 1.0))) / 15;
    }

    final asrAltitude = _r2d(math.atan(1 / (1 + math.tan(_d2r((lat - decl).abs())))));

    DateTime toTime(double hours, {int adjust = ihtiyatMinutes}) {
      final secs = (hours * 3600).round() + adjust * 60;
      // Bulatkan ke atas ke menit berikutnya, seperti jadwal resmi.
      final mins = (secs / 60).ceil();
      return day.add(Duration(minutes: mins));
    }

    return PrayerTimes(
      day,
      toTime(dhuhr - hourAngle(0.833), adjust: -ihtiyatMinutes),
      {
        Prayer.subuh: toTime(dhuhr - hourAngle(fajrAngle)),
        Prayer.dzuhur: toTime(dhuhr),
        Prayer.ashar: toTime(dhuhr + hourAngle(-asrAltitude)),
        Prayer.maghrib: toTime(dhuhr + hourAngle(0.833)),
        Prayer.isya: toTime(dhuhr + hourAngle(ishaAngle)),
      },
    );
  }
}
