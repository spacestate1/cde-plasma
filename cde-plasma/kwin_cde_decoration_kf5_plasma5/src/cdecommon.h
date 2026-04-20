#pragma once

#include <QColor>
#include <algorithm>

namespace CdeKWin
{

/**
 * Shade a color by a percentage (0-255).
 * 100 = unchanged, <100 = darker, >100 = lighter
 */
inline QColor scaledShade(const QColor &base, int percent)
{
    // Clamp percent to valid range to prevent overflow
    percent = std::clamp(percent, 0, 255);

    const auto clampChannel = [](int value) {
        return std::clamp(value, 0, 255);
    };

    return QColor(clampChannel(base.red() * percent / 100),
                  clampChannel(base.green() * percent / 100),
                  clampChannel(base.blue() * percent / 100),
                  base.alpha());
}

// Hard rules for frame border bevels:
// - Light edges use kBevelLightPercent (not higher) to avoid near-white
// - Dark edges use kBevelDarkPercent for clear depth
// - All border bevels (frame, corners, edges, separator) must use these consistently
// - No purple or white colors in any border surface
constexpr int kBevelLightPercent = 120;
constexpr int kBevelDarkPercent = 56;

} // namespace CdeKWin
