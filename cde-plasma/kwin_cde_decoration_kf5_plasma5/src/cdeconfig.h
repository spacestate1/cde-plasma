#pragma once

#include <QColor>
#include <QString>
#include <algorithm>

namespace CdeKWin
{

namespace Config
{

inline const QString configFile = QStringLiteral("cdedecoration");
inline const QString groupName = QStringLiteral("Colors");

// Default values
inline const QColor defaultFrameColor(156, 160, 176);
inline const QColor defaultActiveTitleColor(178, 77, 122);
inline const QColor defaultInactiveTitleColor(156, 160, 176);
inline const QColor defaultActiveTextColor(255, 255, 255);
inline const QColor defaultInactiveTextColor(0, 0, 0);

// Config keys
inline const QString frameColorKey = QStringLiteral("FrameColor");
inline const QString activeTitleColorKey = QStringLiteral("ActiveTitleColor");
inline const QString inactiveTitleColorKey = QStringLiteral("InactiveTitleColor");
inline const QString activeTextColorKey = QStringLiteral("ActiveTextColor");
inline const QString inactiveTextColorKey = QStringLiteral("InactiveTextColor");

// Hard rules for frame color: no white, no purple, not too dark
inline QColor enforceFrameRules(const QColor &c)
{
    int r = std::clamp(c.red(), 100, 210);
    int g = std::clamp(c.green(), 100, 210);
    int b = std::clamp(c.blue(), 100, 210);
    if (b > r + 30) {
        b = r + 30;
    }
    return QColor(r, g, b, c.alpha());
}

} // namespace Config
} // namespace CdeKWin
