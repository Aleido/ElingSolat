#!/usr/bin/env bash
# Generate folder android/ lalu tambahkan izin & konfigurasi untuk notifikasi + lokasi.
# Aman dijalankan berulang kali.
set -euo pipefail
cd "$(dirname "$0")"

command -v flutter >/dev/null || { echo "Flutter belum ter-install. Lihat README.md"; exit 1; }

flutter create --org com.elingsholat --project-name eling_sholat --platforms android .

# Hapus test bawaan template (mengacu ke MyApp yang tidak ada)
if grep -q "MyApp" test/widget_test.dart 2>/dev/null; then rm test/widget_test.dart; fi

MANIFEST=android/app/src/main/AndroidManifest.xml

if ! grep -q "SCHEDULE_EXACT_ALARM" "$MANIFEST"; then
  perl -0pi -e 's|(\s*<application)|
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
    <uses-permission android:name="android.permission.VIBRATE"/>
$1|' "$MANIFEST"

  perl -0pi -e 's|(\s*</application>)|
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
$1|' "$MANIFEST"

  perl -pi -e 's|android:label="eling_sholat"|android:label="Eling Sholat"|' "$MANIFEST"
fi

# Core library desugaring (wajib untuk flutter_local_notifications)
if [ -f android/app/build.gradle.kts ]; then
  G=android/app/build.gradle.kts
  if ! grep -q "isCoreLibraryDesugaringEnabled" "$G"; then
    perl -0pi -e 's|compileOptions \{|compileOptions {\n        isCoreLibraryDesugaringEnabled = true|' "$G"
    printf '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n' >> "$G"
  fi
else
  G=android/app/build.gradle
  if ! grep -q "coreLibraryDesugaringEnabled" "$G"; then
    perl -0pi -e 's|compileOptions \{|compileOptions {\n        coreLibraryDesugaringEnabled true|' "$G"
    printf "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n}\n" >> "$G"
  fi
fi

flutter pub get
echo
echo "✅ Selesai. Sambungkan HP/emulator lalu jalankan: flutter run"
