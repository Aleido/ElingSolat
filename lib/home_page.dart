import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'notification_service.dart';
import 'prayer_calc.dart';
import 'storage.dart';

const _hari = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
const _bulan = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];

String _fmtDate(DateTime d) => '${_hari[d.weekday - 1]}, ${d.day} ${_bulan[d.month - 1]} ${d.year}';
String _hhmm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

class HomePage extends StatefulWidget {
  final Storage storage;
  const HomePage({super.key, required this.storage});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  late AppLocation _loc;
  late DateTime _selected;
  Timer? _ticker;
  bool _locating = false;

  Storage get _storage => widget.storage;

  @override
  void initState() {
    super.initState();
    _loc = _storage.location ?? defaultLocation;
    _selected = _dateOnly(DateTime.now());
    WidgetsBinding.instance.addObserver(this);
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {});
      _reschedule();
    }
  }

  Future<void> _bootstrap() async {
    await NotificationService.requestPermissions();
    if (_storage.location == null) {
      await _useGps(silent: true);
    } else {
      await _reschedule();
    }
  }

  Future<void> _reschedule() => NotificationService.scheduleAll(_loc, _storage);

  Future<void> _setLocation(AppLocation loc) async {
    await _storage.setLocation(loc);
    setState(() => _loc = loc);
    await _reschedule();
  }

  Future<void> _useGps({bool silent = false}) async {
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw 'GPS sedang mati. Nyalakan lokasi lalu coba lagi.';
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        throw 'Izin lokasi ditolak. Pilih kota secara manual.';
      }
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 20),
          ),
        );
      } on TimeoutException {
        pos = await Geolocator.getLastKnownPosition();
      }
      if (pos == null) throw 'Gagal mendapatkan lokasi.';
      await _setLocation(AppLocation(
        'Lokasi GPS (${pos.latitude.toStringAsFixed(2)}, ${pos.longitude.toStringAsFixed(2)})',
        pos.latitude,
        pos.longitude,
      ));
    } catch (e) {
      if (_storage.location == null) await _setLocation(defaultLocation);
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _pickLocation() async {
    final choice = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (ctx, controller) => ListView(
          controller: controller,
          children: [
            ListTile(
              leading: const Icon(Icons.my_location),
              title: const Text('Gunakan lokasi GPS'),
              onTap: () => Navigator.pop(ctx, 'gps'),
            ),
            const Divider(),
            for (final c in cities)
              ListTile(
                leading: const Icon(Icons.location_city),
                title: Text(c.name),
                trailing: c.name == _loc.name ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(ctx, c),
              ),
          ],
        ),
      ),
    );
    if (choice == 'gps') {
      await _useGps();
    } else if (choice is AppLocation) {
      await _setLocation(choice);
    }
  }

  Future<void> _toggle(Prayer p, bool value) async {
    await _storage.setDone(_selected, p, value);
    setState(() {});
    await _reschedule(); // batalkan/aktifkan lagi pengingat "sudah sholat?"
  }

  /// Sholat berikutnya (hari ini atau Subuh besok).
  (Prayer, DateTime) _nextPrayer(DateTime now) {
    final today = PrayerCalculator.calculate(now, _loc.lat, _loc.lng);
    for (final p in Prayer.values) {
      if (today[p].isAfter(now)) return (p, today[p]);
    }
    final tomorrow = PrayerCalculator.calculate(now.add(const Duration(days: 1)), _loc.lat, _loc.lng);
    return (Prayer.subuh, tomorrow[Prayer.subuh]);
  }

  String _countdown(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60 + (d.inSeconds % 60 > 0 ? 1 : 0);
    if (h == 0) return '$m menit lagi';
    return '$h jam $m menit lagi';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final todayDate = _dateOnly(now);
    final isToday = _selected == todayDate;
    final times = PrayerCalculator.calculate(_selected, _loc.lat, _loc.lng);
    final done = _storage.doneOn(_selected);
    final (nextP, nextT) = _nextPrayer(now);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Eling Sholat'),
        actions: [
          IconButton(
            tooltip: 'Ganti lokasi',
            onPressed: _locating ? null : _pickLocation,
            icon: _locating
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.place_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: scheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sholat berikutnya', style: TextStyle(color: scheme.onPrimaryContainer)),
                  const SizedBox(height: 4),
                  Text(
                    '${nextP.label} · ${_hhmm(nextT)}',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(_countdown(nextT.difference(now)), style: TextStyle(color: scheme.onPrimaryContainer)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.place, size: 16, color: scheme.onPrimaryContainer),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(_loc.name,
                            style: TextStyle(color: scheme.onPrimaryContainer), overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _selected = _selected.subtract(const Duration(days: 1))),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: InkWell(
                  onTap: isToday ? null : () => setState(() => _selected = todayDate),
                  child: Column(
                    children: [
                      Text(_fmtDate(_selected),
                          style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
                      if (!isToday)
                        Text('Ketuk untuk kembali ke hari ini',
                            style: TextStyle(fontSize: 12, color: scheme.primary)),
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: isToday ? null : () => setState(() => _selected = _selected.add(const Duration(days: 1))),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(value: done.length / 5, minHeight: 10),
                  ),
                ),
                const SizedBox(width: 12),
                Text('${done.length}/5', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          if (done.length == 5)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Alhamdulillah, sholat hari ini lengkap 🎉',
                  textAlign: TextAlign.center, style: TextStyle(color: scheme.primary)),
            ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                for (final p in Prayer.values) _prayerTile(p, times[p], done.contains(p), now, isToday, nextP),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.wb_twilight),
                  title: const Text('Terbit'),
                  trailing: Text(_hhmm(times.sunrise)),
                  enabled: false,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Perhitungan: Kemenag RI (Subuh 20°, Isya 18°, ihtiyat 2 menit). '
            'Jika belum dicentang, pengingat ulang muncul ${NotificationService.followUpMinutes} menit setelah adzan.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _prayerTile(Prayer p, DateTime time, bool isDone, DateTime now, bool isToday, Prayer nextP) {
    final scheme = Theme.of(context).colorScheme;
    final arrived = !time.isAfter(now);
    final isNext = isToday && p == nextP && !arrived;

    String? status;
    Color? statusColor;
    if (isDone) {
      status = 'Sudah sholat';
      statusColor = scheme.primary;
    } else if (arrived) {
      status = 'Belum dicentang';
      statusColor = scheme.error;
    } else if (isNext) {
      status = 'Berikutnya';
      statusColor = scheme.tertiary;
    }

    return CheckboxListTile(
      value: isDone,
      // Hanya bisa dicentang jika waktunya sudah masuk.
      onChanged: arrived ? (v) => _toggle(p, v ?? false) : null,
      tileColor: isNext ? scheme.secondaryContainer.withValues(alpha: 0.4) : null,
      title: Text(p.label, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: status == null ? null : Text(status, style: TextStyle(color: statusColor)),
      secondary: Text(
        _hhmm(time),
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
      ),
    );
  }
}
