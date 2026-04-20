#include "cdebutton.h"

#include "cdecommon.h"
#include "cdedecoration.h"

#include <QPainter>
#include <QPen>

#include <algorithm>

namespace CdeKWin
{

namespace
{

constexpr int kCloseMinPad = 4;
constexpr int kCloseMaxPad = 6;
constexpr int kCloseStroke = 2;

void drawBevel(QPainter *painter, const QRect &rect, const QColor &fill, bool sunken, int thickness = 1)
{
    if (rect.width() <= 0 || rect.height() <= 0) {
        return;
    }

    const int lw = std::max(1, thickness);
    const QColor light = sunken ? scaledShade(fill, kBevelDarkPercent) : scaledShade(fill, kBevelLightPercent);
    const QColor dark = sunken ? scaledShade(fill, kBevelLightPercent) : scaledShade(fill, kBevelDarkPercent);

    // Fill the interior (excluding bevel edges)
    const QRect interior = rect.adjusted(lw, lw, -lw, -lw);
    if (interior.width() > 0 && interior.height() > 0) {
        painter->fillRect(interior, fill);
    }

    // Draw light edges (top and left) as filled rectangles
    // Top edge: full width band, lw pixels tall
    painter->fillRect(QRect(rect.left(), rect.top(), rect.width(), lw), light);
    // Left edge: from below top band to bottom-lw, lw pixels wide
    painter->fillRect(QRect(rect.left(), rect.top() + lw, lw, rect.height() - lw * 2), light);

    // Draw dark edges (bottom and right) as filled rectangles
    // Bottom edge: full width band, lw pixels tall
    painter->fillRect(QRect(rect.left(), rect.bottom() - lw + 1, rect.width(), lw), dark);
    // Right edge: from top to above bottom band, lw pixels wide
    painter->fillRect(QRect(rect.right() - lw + 1, rect.top(), lw, rect.height() - lw), dark);

    // Fix the corners where light and dark meet - draw diagonal separation
    for (int i = 0; i < lw; ++i) {
        // Bottom-left corner: light gets the upper-left triangle
        painter->setPen(light);
        painter->drawLine(rect.left() + i, rect.bottom() - lw + 1,
                          rect.left() + i, rect.bottom() - i);
        // Top-right corner: light gets the lower-left triangle
        painter->drawLine(rect.right() - lw + 1, rect.top() + i,
                          rect.right() - i - 1, rect.top() + i);
    }
}

QColor adjustFill(const QColor &base, bool hovered, bool pressed, bool enabled)
{
    if (!enabled) {
        return scaledShade(base, 92);
    }
    if (pressed) {
        return scaledShade(base, 84);
    }
    if (hovered) {
        return scaledShade(base, 96);
    }
    return base;
}

} // namespace

CdeButton::CdeButton(KDecoration3::DecorationButtonType type,
                     KDecoration3::Decoration *decoration,
                     QObject *parent)
    : KDecoration3::DecorationButton(type, decoration, parent)
{
}

void CdeButton::paint(QPainter *painter, const QRectF &repaintArea)
{
    Q_UNUSED(repaintArea)

    if (!isVisible()) {
        return;
    }

    const auto *cde = cdeDecoration();
    if (!cde) {
        return;
    }

    const QRect rect = geometry().toAlignedRect();
    const bool pressed = isPressed();
    const bool hovered = isHovered();
    const bool enabled = isEnabled();

    painter->save();
    painter->setRenderHint(QPainter::Antialiasing, false);

    QColor fill = adjustFill(cde->titleBaseColor(), hovered, pressed, enabled);
    if (type() == KDecoration3::DecorationButtonType::Close && (hovered || pressed)) {
        fill = adjustFill(cde->warningColor(), hovered, pressed, enabled);
    }

    drawBevel(painter, rect, fill, pressed, 1);

    switch (type()) {
    case KDecoration3::DecorationButtonType::Menu:
        paintMenuGlyph(painter, rect);
        break;
    case KDecoration3::DecorationButtonType::Minimize:
        paintMinimizeGlyph(painter, rect);
        break;
    case KDecoration3::DecorationButtonType::Maximize:
        paintMaximizeGlyph(painter, rect);
        break;
    case KDecoration3::DecorationButtonType::Close:
        paintCloseGlyph(painter, rect);
        break;
    default:
        break;
    }

    painter->restore();
}

CdeDecoration *CdeButton::cdeDecoration() const
{
    return qobject_cast<CdeDecoration *>(decoration());
}

void CdeButton::paintMenuGlyph(QPainter *painter, const QRect &rect) const
{
    const auto *cde = cdeDecoration();
    if (!cde) {
        return;
    }

    const int handleHeight = std::max(4, rect.height() / 5);
    const QRect handle(rect.left() + 4,
                       rect.center().y() - handleHeight / 2,
                       std::max(0, rect.width() - 8),
                       handleHeight);
    drawBevel(painter, handle, cde->titleBaseColor(), isPressed(), 1);
}

void CdeButton::paintMinimizeGlyph(QPainter *painter, const QRect &rect) const
{
    const auto *cde = cdeDecoration();
    if (!cde) {
        return;
    }

    const int dim = rect.height() < 12 ? 3 : 4;
    const QRect dot(rect.center().x() - dim / 2,
                    rect.center().y() - dim / 2,
                    dim,
                    dim);
    drawBevel(painter, dot, cde->titleBaseColor(), isPressed(), 1);
}

void CdeButton::paintMaximizeGlyph(QPainter *painter, const QRect &rect) const
{
    const auto *cde = cdeDecoration();
    if (!cde) {
        return;
    }

    const int dim = std::max(5, rect.height() - 8);
    const QRect outer(rect.center().x() - dim / 2,
                      rect.center().y() - dim / 2,
                      dim,
                      dim);
    if (isChecked()) {
        drawBevel(painter, outer.adjusted(2, 0, -2, -2), cde->titleBaseColor(), isPressed(), 1);
        drawBevel(painter, outer.adjusted(0, 2, -2, -2), cde->titleBaseColor(), isPressed(), 1);
    } else {
        drawBevel(painter, outer, cde->titleBaseColor(), isPressed(), 1);
    }
}

void CdeButton::paintCloseGlyph(QPainter *painter, const QRect &rect) const
{
    const auto *cde = cdeDecoration();
    if (!cde) {
        return;
    }

    const int size = std::min(rect.width(), rect.height());
    const int pad = std::clamp(size / 4, kCloseMinPad, kCloseMaxPad);
    const QColor color = isEnabled() ? cde->textColor() : scaledShade(cde->textColor(), 75);

    QPen pen(color, kCloseStroke);
    pen.setCosmetic(true);
    painter->setPen(pen);

    const QPoint topLeft(rect.left() + pad, rect.top() + pad);
    const QPoint topRight(rect.right() - pad, rect.top() + pad);
    const QPoint bottomLeft(rect.left() + pad, rect.bottom() - pad);
    const QPoint bottomRight(rect.right() - pad, rect.bottom() - pad);

    painter->drawLine(topLeft, bottomRight);
    painter->drawLine(topRight, bottomLeft);
}

} // namespace CdeKWin
