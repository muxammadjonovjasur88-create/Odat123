Place the required TTF font files here before building the app.

Required filenames (referenced by pubspec.yaml):
- Poppins-Regular.ttf
- Poppins-Medium.ttf
- Poppins-SemiBold.ttf
- Inter-Regular.ttf
- Inter-Medium.ttf
- Inter-SemiBold.ttf

Recommended source: https://fonts.google.com/

After adding the files run:

```bash
flutter pub get
flutter clean
flutter build apk --release
```

Notes:
- Ensure the filenames exactly match those listed above.
- If you prefer other weights, update `pubspec.yaml` to reference the filenames you add.
