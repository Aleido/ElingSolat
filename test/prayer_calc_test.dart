import 'package:eling_sholat/prayer_calc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('waktu sholat Jakarta masuk akal & berurutan', () {
    final t = PrayerCalculator.calculate(DateTime(2026, 11, 20), -6.2088, 106.8456);
    final order = Prayer.values.map((p) => t[p]).toList();
    for (var i = 1; i < order.length; i++) {
      expect(order[i].isAfter(order[i - 1]), isTrue);
    }
    // Referensi jadwal Kemenag Jakarta ± beberapa menit (asumsi zona waktu device WIB).
    if (DateTime(2026, 11, 20).timeZoneOffset == const Duration(hours: 7)) {
      expect(t[Prayer.subuh].hour, 4);
      expect(t[Prayer.dzuhur].hour, 11);
      expect(t[Prayer.maghrib].hour, 17);
      expect(t[Prayer.isya].hour, 19);
    }
  });
}
