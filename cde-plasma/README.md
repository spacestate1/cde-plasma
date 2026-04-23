# CDE Plasma Theme

A complete Common Desktop Environment (CDE) theme for KDE Plasma 6, featuring the classic blue-gray color scheme with beveled 3D controls.

## Screenshots

### Color Palette Demo
Six color variations showing the CDE beveled window style with custom borders, title bars, and flat progress bars.

![Color Variations](screenshots/windows1.png)

### Desktop
CDE-themed Plasma desktop with beveled window decorations, application menu, and taskbar.

![Desktop](screenshots/windows2.png)

![Desktop with Menu](screenshots/windows3.png)

### SDDM Login
CDE-styled login screen with beveled window frame, user/password fields, and session selector.

![SDDM Login](screenshots/windows4.png)

## Components

- **KWin Decoration** — Window frames with CDE-style beveled borders, L-shaped resize corners, and titlebar buttons
- **Qt Widget Style** — Buttons, scrollbars, menus, flat progress bars with CDE appearance
- **Plasma Theme** — Panel, system tray, and plasmoid styling
- **SDDM Login Theme** — CDE-styled login screen with window frame
- **Lock Screen** — CDE-styled lock screen matching the SDDM login
- **Color Scheme** — Blue-gray palette matching classic CDE
- **Cursor Theme** — Hackneyed retro cursor (auto-downloaded or from ~/Downloads)
- **Demo Script** — Six-window color palette showcase for screenshots

## Requirements

- KDE Plasma 6
- For distro packages: just the package manager. No toolchain.
- For source build: Qt 6, CMake, g++, pkg-config, extra-cmake-modules, KF6 CoreAddons, KDecoration3, KCMUtils. The installer pulls these in for you.

## Installation

### From a release package (recommended)

Grab the latest release for your distro from the [Releases page](https://github.com/spacestate1/cde-plasma/releases):

| Distro | File | Install |
| --- | --- | --- |
| Arch / Manjaro / EndeavourOS | `cde-plasma-VERSION-1-x86_64.pkg.tar.zst` | `sudo pacman -U cde-plasma-*.pkg.tar.zst` |
| Debian 13 (Trixie) | `cde-plasma_VERSION-1_amd64_debian.deb` | `sudo apt install ./cde-plasma_*_debian.deb` |
| Ubuntu 24.10 | `cde-plasma_VERSION-1_amd64_ubuntu.deb` | `sudo apt install ./cde-plasma_*_ubuntu.deb` |
| Fedora 40+ | `cde-plasma-VERSION-1.fc40.x86_64.rpm` | `sudo dnf install cde-plasma-*.rpm` |

Then activate the theme as your normal user (not root):

```bash
cde-plasma-apply
```

To revert later without uninstalling:

```bash
cde-plasma-unapply
```

### From source (any distro)

```bash
./install.sh        # interactive
./install.sh -y     # auto-yes (no prompts, good for SSH)
```

The installer detects your distro (Arch/Ubuntu/Fedora), pulls in the build dependencies, compiles the KWin decoration and Qt style, installs the asset directories, and configures KDE. Logs land in `logs/install-YYYYMMDD-HHMMSS.log`.

### Remote / Headless Install

```bash
scp -r cde-plasma user@host:~/cde-plasma
ssh user@host "cd ~/cde-plasma && bash install.sh -y"
```

## Cutting a release (maintainers)

Release packages are built by `.github/workflows/release.yml`. Trigger a release by pushing a `v*` tag:

```bash
git tag v0.1.0
git push origin v0.1.0
```

The workflow builds packages for Arch, Debian, Ubuntu, and Fedora in parallel matrix jobs (each in its own distro container) and attaches the `.pkg.tar.zst` / `.deb` / `.rpm` files to a GitHub Release.

For testing without cutting a tag, use the workflow's manual dispatch — packages get built and uploaded as workflow artifacts, but no Release is created.

To build a single package locally:

```bash
bash cde-plasma/packaging/build-arch.sh   0.1.0   # produces dist/*.pkg.tar.zst
bash cde-plasma/packaging/build-debian.sh 0.1.0   # produces dist/*.deb
bash cde-plasma/packaging/build-fedora.sh 0.1.0   # produces dist/*.rpm
```

## Uninstallation

```bash
./uninstall.sh
```

To restore the original lock screen:
```bash
sudo cp -r /usr/share/plasma/shells/org.kde.plasma.desktop/contents/lockscreen.breeze-backup/* \
           /usr/share/plasma/shells/org.kde.plasma.desktop/contents/lockscreen/
```

## Manual Activation

After installation, activate via System Settings:

- **Window Decorations**: Appearance > Window Decorations > CDE Frame
- **Application Style**: Appearance > Application Style > CDE
- **Plasma Style**: Appearance > Plasma Style > Commonality
- **Colors**: Appearance > Colors > CDE Blue-Gray
- **Cursors**: Appearance > Cursors > Hackneyed-48px

Log out and back in to see the SDDM login theme.

## Demo

Run the color palette demo to see all six CDE variations:

```bash
python3 demo/cde_demo.py
```

## License

MIT License
