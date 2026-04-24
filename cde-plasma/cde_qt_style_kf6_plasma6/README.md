`cde_qt_style_kf6_plasma6` is a Qt6 widget style plugin for Plasma 6 systems. It supplies the client-side pieces the KWin decoration cannot draw: recessed content frames, scroll-area seams, and CDE-like scrollbars.

Build:

```bash
cmake -S cde_qt_style_kf6_plasma6 -B cde_qt_style_kf6_plasma6/build
cmake --build cde_qt_style_kf6_plasma6/build -j"$(nproc)"
```

Install on a Qt6/Plasma 6 system:

```bash
sudo cmake --install cde_qt_style_kf6_plasma6/build
kwriteconfig6 --file ~/.config/kdeglobals --group KDE --key widgetStyle CDE
```

New Qt applications will pick the style up after restart. Existing running applications need to be closed and reopened.
