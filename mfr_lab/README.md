# MFR Virtual Lab

A Flutter mobile application for Chemical Engineering students to conduct **virtual Mixed Flow Reactor (MFR) experiments** and determine a hidden rate constant **k** through experimentation and graphical analysis.

---

## 🚀 Getting Started (After Installing Flutter)

1. **Install Flutter** from [flutter.dev](https://flutter.dev/docs/get-started/install/windows) and ensure `flutter` is on your PATH.

2. **Set up `local.properties`** in the `android/` folder:
   ```
   sdk.dir=C:\\Users\\<YOU>\\AppData\\Local\\Android\\sdk
   flutter.sdk=C:\\flutter
   flutter.versionCode=1
   flutter.versionName=1.0.0
   ```

3. **Install dependencies:**
   ```bash
   flutter pub get
   ```

4. **Run the app:**
   ```bash
   flutter run
   ```

---

## 📁 Project Structure

```
lib/
  main.dart                    ← App entry point, theme, routing
  models/
    trial_model.dart           ← Data class for a single MFR trial
  providers/
    experiment_provider.dart   ← Session state (ChangeNotifier)
  screens/
    setup_screen.dart          ← Screen 1: Fixed session inputs
    trial_screen.dart          ← Screen 2: Per-trial experiments
    results_screen.dart        ← Screen 3: Analysis & k submission
  widgets/
    input_field.dart           ← Labeled numeric input widget
    trial_table.dart           ← Data table of all trials
    mfr_graph.dart             ← Y vs τ scatter chart (fl_chart)
    reactor_diagram.dart       ← Animated reactor illustration
  utils/
    mfr_solver.dart            ← Newton-Raphson MFR solver
    excel_exporter.dart        ← Excel file generator & sharer
```

---

## 🔬 Chemistry Background

- **Reaction:** A + B → C
- **Rate law:** (−r_A) = k · C_A · C_B
- **Design equation:** k · C_A0 · τ · (1 − X_A)(m − X_A) − X_A = 0
- **k range (hidden):** 0.25 – 0.50 L/(mol·min)

---

## 📦 Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| provider | ^6.1.2 | State management |
| fl_chart | ^0.68.0 | Y vs τ scatter chart |
| excel | ^4.0.6 | Export trial data to Excel |
| path_provider | ^2.1.2 | File system access |
| share_plus | ^9.0.0 | Share Excel file |
| intl | ^0.19.0 | Number formatting |
