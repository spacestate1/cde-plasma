#pragma once

#include <QColor>
#include <QString>
#include <algorithm>

namespace CdeKWin
{

namespace Config
{

// Stored in kwinrc (a LookAndFeel-allowlisted config file) under a dedicated
// group so Plasma's Global Theme apply can write these through the standard
// kdedefaults mechanism. The older separate `cdedecoration` file is no longer
// used; migrateFromLegacyConfig() copies any pre-existing values once.
inline const QString configFile = QStringLiteral("kwinrc");
inline const QString groupName = QStringLiteral("org.kde.cde.decoration");
inline const QString legacyConfigFile = QStringLiteral("cdedecoration");
inline const QString legacyGroupName  = QStringLiteral("Colors");

// Default values (light preset)
inline const QColor defaultFrameColor(156, 160, 176);
inline const QColor defaultActiveTitleColor(178, 77, 122);
inline const QColor defaultInactiveTitleColor(156, 160, 176);
inline const QColor defaultActiveTextColor(255, 255, 255);
inline const QColor defaultInactiveTextColor(0, 0, 0);

// Dark preset — genuinely dark. Frame luminance is deliberately kept
// in the 50–80 range so the multiplicative bevel shades in cdecommon.h
// (120% light, 56% dark) still produce visible depth on the edges.
// Active/inactive title colors lean purple to pair with the light
// preset's pink-magenta accent; enforceFrameRules does not apply to
// titles, so the b>r+30 "no purple" rule doesn't constrain them here.
inline const QColor darkFrameColor(55, 60, 75);
inline const QColor darkActiveTitleColor(111, 82, 153);
inline const QColor darkInactiveTitleColor(52, 13, 55);
inline const QColor darkActiveTextColor(255, 255, 255);
inline const QColor darkInactiveTextColor(170, 170, 170);

// Chartreuse preset — a sharp acid-green take that still keeps enough frame
// contrast for the bevel shading to read cleanly.
inline const QColor chartreuseFrameColor(138, 154, 72);
inline const QColor chartreuseActiveTitleColor(177, 214, 44);
inline const QColor chartreuseInactiveTitleColor(108, 122, 57);
inline const QColor chartreuseActiveTextColor(0, 0, 0);
inline const QColor chartreuseInactiveTextColor(0, 0, 0);

// Electric pink preset — loud hot pink title with a complementary teal
// inactive state so the pair feels intentionally high-contrast.
inline const QColor electricFrameColor(166, 124, 146);
inline const QColor electricActiveTitleColor(232, 52, 166);
inline const QColor electricInactiveTitleColor(0, 168, 136);
inline const QColor electricActiveTextColor(255, 255, 255);
inline const QColor electricInactiveTextColor(0, 0, 0);

// Config keys
inline const QString frameColorKey = QStringLiteral("FrameColor");
inline const QString activeTitleColorKey = QStringLiteral("ActiveTitleColor");
inline const QString inactiveTitleColorKey = QStringLiteral("InactiveTitleColor");
inline const QString activeTextColorKey = QStringLiteral("ActiveTextColor");
inline const QString inactiveTextColorKey = QStringLiteral("InactiveTextColor");

// Hard rules for frame color: no white, no purple, keep bevels visible.
// Min 30 leaves enough luminance for the multiplicative bevel shades
// (kBevelLightPercent/kBevelDarkPercent in cdecommon.h) to stay visible
// on dark frames while still preventing unusable near-black values.
inline QColor enforceFrameRules(const QColor &c)
{
    int r = std::clamp(c.red(), 30, 210);
    int g = std::clamp(c.green(), 30, 210);
    int b = std::clamp(c.blue(), 30, 210);
    if (b > r + 30) {
        b = r + 30;
    }
    return QColor(r, g, b, c.alpha());
}

} // namespace Config
} // namespace CdeKWin
