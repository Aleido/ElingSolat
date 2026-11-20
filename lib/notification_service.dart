import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'prayer_calc.dart';
import 'storage.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  /// Berapa hari ke depan notifikasi dijadwalkan. Jadwal diperbarui setiap app dibuka.
  static const _daysAhead = 7;

  /// Pengingat ulang jika belum dicentang setelah sekian menit.
  static const followUpMinutes = 30;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'waktu_sholat',
      'Waktu Sholat',
      channelDescription: 'Pengingat masuk waktu sholat',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
    ),
  );

  static const _followUpDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'cek_sholat',
      'Pengingat Checklist',
      channelDescription: 'Mengingatkan jika sholat belum dicentang',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  static Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
    }
    await _plugin.initialize(
      const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
    );
  }

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  static Future<void> requestPermissions() async {
    await _android?.requestNotificationsPermission();
    if (!(await _android?.canScheduleExactNotifications() ?? true)) {
      await _android?.requestExactAlarmsPermission();
    }
  }

  static int _dayNumber(DateTime d) => DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;

  /// ID unik per (tanggal, sholat). Follow-up memakai offset 50.
  static int _id(DateTime d, Prayer p, {bool followUp = false}) =>
      (_dayNumber(d) % 10000) * 100 + p.index + (followUp ? 50 : 0);

  /// Batalkan semua lalu jadwalkan ulang untuk beberapa hari ke depan.
  static Future<void> scheduleAll(AppLocation loc, Storage storage) async {
    await _plugin.cancelAll();
    final exact = await _android?.canScheduleExactNotifications() ?? false;
    final mode = exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (var i = 0; i < _daysAhead; i++) {
      final day = today.add(Duration(days: i));
      final times = PrayerCalculator.calculate(day, loc.lat, loc.lng);
      final done = storage.doneOn(day);

      for (final p in Prayer.values) {
        final t = times[p];
        if (t.isAfter(now)) {
          await _plugin.zonedSchedule(
            _id(day, p),
            'Waktu ${p.label} telah tiba',
            '${_hhmm(t)} · ${loc.name}. Jangan lupa centang setelah sholat 🤲',
            tz.TZDateTime.from(t, tz.local),
            _details,
            androidScheduleMode: mode,
          );
        }

        // Follow-up hanya jika belum dicentang dan masih sebelum waktu sholat berikutnya.
        final followUp = t.add(const Duration(minutes: followUpMinutes));
        final nextIdx = p.index + 1;
        final limit = nextIdx < Prayer.values.length ? times[Prayer.values[nextIdx]] : day.add(const Duration(days: 1));
        if (!done.contains(p) && followUp.isAfter(now) && followUp.isBefore(limit)) {
          await _plugin.zonedSchedule(
            _id(day, p, followUp: true),
            'Sudah sholat ${p.label}?',
            'Kalau sudah, buka aplikasi dan centang ✅',
            tz.TZDateTime.from(followUp, tz.local),
            _followUpDetails,
            androidScheduleMode: mode,
          );
        }
      }
    }
  }

  static String _hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
