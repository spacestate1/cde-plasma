Name:           cde-plasma
Version:        0.1.0
Release:        1%{?dist}
Summary:        Common Desktop Environment (CDE) theme for KDE Plasma 6

License:        MIT
URL:            https://github.com/spacestate1/cde-plasma
Source0:        %{url}/archive/refs/tags/v%{version}.tar.gz

BuildRequires:  cmake
BuildRequires:  extra-cmake-modules
BuildRequires:  gcc-c++
BuildRequires:  pkgconfig
BuildRequires:  qt6-qtbase-devel
BuildRequires:  qt6-qtbase-private-devel
BuildRequires:  kf6-kcoreaddons-devel
BuildRequires:  kf6-kconfig-devel
BuildRequires:  kf6-kconfigwidgets-devel
BuildRequires:  kf6-kcmutils-devel
BuildRequires:  kf6-kwidgetsaddons-devel
BuildRequires:  kf6-kcolorscheme-devel
BuildRequires:  kdecoration-devel

Requires:       plasma-workspace
Recommends:     sddm
Suggests:       hackneyed-cursor-theme

# Plasma 6 / Qt 6 only for now.
ExclusiveArch:  x86_64 aarch64

%description
A complete recreation of the early-90s Common Desktop Environment look for
KDE Plasma 6:

 - KWin window decoration with beveled borders and L-shaped resize corners
 - Qt widget style (buttons, scrollbars, flat progress bars)
 - Plasma desktop theme (panel, system tray, plasmoids)
 - SDDM login theme
 - Lock screen overlay
 - Multiple bundled color schemes (Blue-Gray, Dark, Chartreuse, Electric Pink, Classic)

After installation, run `cde-plasma-apply` as your user to switch to the
theme. Run `cde-plasma-unapply` to revert (the package stays installed).

%prep
%autosetup -n %{name}-%{version}

%build
cd cde-plasma

cmake -B build-decoration -S kwin_cde_decoration_kf6_plasma6 \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo
cmake --build build-decoration %{?_smp_mflags}

cmake -B build-style -S cde_qt_style_kf6_plasma6 \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo
cmake --build build-style %{?_smp_mflags}

cmake -B build-assets -S . \
    -DCMAKE_INSTALL_PREFIX=/usr

%install
cd cde-plasma
DESTDIR=%{buildroot} cmake --install build-decoration
DESTDIR=%{buildroot} cmake --install build-style
DESTDIR=%{buildroot} cmake --install build-assets

%files
%license LICENSE
%doc README.md
%{_libdir}/qt6/plugins/org.kde.kdecoration3/org.kde.cde.decoration.so
%{_libdir}/qt6/plugins/org.kde.kdecoration3.kcm/kcm_cdedecoration.so
%{_libdir}/qt6/plugins/styles/cde_qt_style.so
%{_datadir}/color-schemes/CDE.colors
%{_datadir}/color-schemes/CDE-Dark.colors
%{_datadir}/color-schemes/CDE-Chartreuse.colors
%{_datadir}/color-schemes/CDE-ElectricPink.colors
%{_datadir}/color-schemes/CDE-Classic.colors
%{_datadir}/plasma/desktoptheme/commonality/
%{_datadir}/plasma/desktoptheme/commonality-dark/
%{_datadir}/plasma/desktoptheme/commonality-classic/
%{_datadir}/plasma/look-and-feel/org.kde.cde.desktop/
%{_datadir}/plasma/look-and-feel/org.kde.cde-dark.desktop/
%{_datadir}/sddm/themes/sddm-cde/
%{_datadir}/cde-plasma/
%{_bindir}/cde-plasma-apply
%{_bindir}/cde-plasma-unapply
%{_bindir}/cde-plasma-mode

%changelog
* Wed Apr 22 2026 Connor McRann <cmcrann@protonmail.com> - 0.1.0-1
- Initial release.
