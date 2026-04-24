# KWin CDE Decoration (KF6)

This is a C++ KWin decoration plugin for Plasma 6 / KDecoration3 that ports the custom titlebar work from the Xlib prototype into the KDE decoration layer.

It focuses on decoration-only behavior:

- custom `X` close button glyph
- custom beveled menu, minimize, maximize, and close buttons
- hover and pressed feedback on title buttons
- resize-edge and resize-corner hover highlights
- a CDE-like beveled frame and titlebar

It does not attempt to change client-side content such as scrollbars, terminal transparency, or word-processor menus. KWin decorations cannot control those areas.

## Build

You need a Plasma 6 / Qt 6 development environment with:

- `ECM`
- `Qt6::Core`
- `Qt6::Gui`
- `Qt6::Widgets`
- `KF6::CoreAddons`
- `KF6::ConfigWidgets`
- `KF6::KCMUtils`
- `KF6::WidgetsAddons`
- `KDecoration3`

Example:

```bash
cmake -S kwin_cde_decoration_kf6_plasma6 -B build/kwin_cde_decoration_kf6_plasma6 -DCMAKE_BUILD_TYPE=RelWithDebInfo
cmake --build build/kwin_cde_decoration_kf6_plasma6
cmake --install build/kwin_cde_decoration_kf6_plasma6 --prefix ~/.local
```

The plugin installs to:

```text
${KDE_INSTALL_PLUGINDIR}/org.kde.kdecoration3
```

## Enable

After installing, restart KWin or log out and back in, then select the decoration in System Settings.

On X11 a common test loop is:

```bash
kwin_x11 --replace
```

On Wayland you normally test by restarting the Plasma session.

## Notes

- This project targets the Plasma 6 `KDecoration3` API.
- It exists alongside the Plasma 5 `kwin_cde_decoration_kf5_plasma5` variant in the same workspace.
