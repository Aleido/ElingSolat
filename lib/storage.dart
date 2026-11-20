import 'package:shared_preferences/shared_preferences.dart';

import 'prayer_calc.dart';

class AppLocation {
  final String name;
  final double lat;
  final double lng;
  const AppLocation(this.name, this.lat, this.lng);
}

const defaultLocation = AppLocation('Jakarta', -6.2088, 106.8456);

const cities = <AppLocation>[
  AppLocation('Jakarta', -6.2088, 106.8456),
  AppLocation('Bandung', -6.9175, 107.6191),
  AppLocation('Semarang', -6.9667, 110.4167),
  AppLocation('Yogyakarta', -7.7956, 110.3695),
  AppLocation('Surabaya', -7.2575, 112.7521),
  AppLocation('Malang', -7.9666, 112.6326),
  AppLocation('Denpasar', -8.6705, 115.2126),
  AppLocation('Medan', 3.5952, 98.6722),
  AppLocation('Padang', -0.9471, 100.4172),
  AppLocation('Pekanbaru', 0.5071, 101.4478),
  AppLocation('Palembang', -2.9761, 104.7754),
  AppLocation('Banda Aceh', 5.5483, 95.3238),
  AppLocation('Pontianak', -0.0263, 109.3425),
  AppLocation('Banjarmasin', -3.3186, 114.5944),
  AppLocation('Balikpapan', -1.2379, 116.8529),
  AppLocation('Makassar', -5.1477, 119.4327),
  AppLocation('Manado', 1.4748, 124.8421),
  AppLocation('Mataram', -8.5833, 116.1167),
  AppLocation('Ambon', -3.6954, 128.1814),
  AppLocation('Jayapura', -2.5337, 140.7181),
];

class Storage {
  final SharedPreferences _p;
  Storage._(this._p);

  static Future<Storage> load() async => Storage._(await SharedPreferences.getInstance());

  AppLocation? get location {
    final lat = _p.getDouble('lat');
    final lng = _p.getDouble('lng');
    if (lat == null || lng == null) return null;
    return AppLocation(_p.getString('locName') ?? 'Lokasi saya', lat, lng);
  }

  Future<void> setLocation(AppLocation l) async {
    await _p.setDouble('lat', l.lat);
    await _p.setDouble('lng', l.lng);
    await _p.setString('locName', l.name);
  }

  static String _key(DateTime d) =>
      'done_${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Set<Prayer> doneOn(DateTime d) {
    final names = _p.getStringList(_key(d)) ?? const [];
    final map = Prayer.values.asNameMap();
    return names.map((n) => map[n]).whereType<Prayer>().toSet();
  }

  bool isDone(DateTime d, Prayer p) => doneOn(d).contains(p);

  Future<void> setDone(DateTime d, Prayer p, bool done) async {
    final set = doneOn(d);
    done ? set.add(p) : set.remove(p);
    await _p.setStringList(_key(d), set.map((e) => e.name).toList());
  }
}
