`cde_qt_style_kf5_plasma5` is a Qt5 widget style plugin for Plasma 5 systems. It supplies the client-side pieces the KWin decoration cannot draw: recessed content frames, scroll-area seams, and CDE-like scrollbars.

Build:

```bash
cmake -S cde_qt_style_kf5_plasma5 -B cde_qt_style_kf5_plasma5/build
cmake --build cde_qt_style_kf5_plasma5/build -j"$(nproc)"
```

Install on a Qt5/Plasma 5 system:

```bash
sudo cmake --install cde_qt_style_kf5_plasma5/build
kwriteconfig5 --file ~/.config/kdeglobals --group KDE --key widgetStyle CdeKF5
```

New Qt applications will pick the style up after restart. Existing running applications need to be closed and reopened.
