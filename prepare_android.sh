#!/usr/bin/env bash
set -e
flutter create . --platforms=android
python3 - <<'PY'
from pathlib import Path
p=Path("android/app/src/main/AndroidManifest.xml")
s=p.read_text()
perm='    <uses-permission android:name="android.permission.INTERNET" />\n'
if 'android.permission.INTERNET' not in s:
    s=s.replace('<manifest xmlns:android="http://schemas.android.com/apk/res/android">', '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n'+perm)
p.write_text(s)
PY
