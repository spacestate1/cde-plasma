#include "cdedecoration.h"

#include "cdebutton.h"
#include "cdecommon.h"
#include "cdeconfig.h"

#include <QFontMetrics>
#include <QPainter>
#include <QRegion>

#include <KConfig>
#include <KConfigGroup>

#include <algorithm>

#include <kdecoration3/decoratedwindow.h>
#include <kdecoration3/decorationsettings.h>

namespace CdeKWin
{

namespace
{

constexpr int kBaseBorderWidth = 7;      // Total border thickness (Normal size)
constexpr int kBaseTitleHeight = 22;
constexpr int kBaseTitlePadding = 6;
constexpr int kBaseResizeOnlyWidth = 6;
constexpr int kOuterBevelWidth = 2;       // Outer raised bevel
constexpr int kInnerBevelWidth = 1;       // Inner sunken bevel around client
constexpr int kInnerLineWidth = 1;

// Frame border color hard rules are enforced at runtime in Config::enforceFrameRules()
// (cdeconfig.h): no white, no purple, not too dark, must differ from window background.
// Colors are user-configurable via the KCM, stored in ~/.config/cdedecoration

// Returns a scale factor based on BorderSize setting
// Normal = 1.0, Tiny = 0.5, Large = 1.5, etc.
qreal borderSizeScale(KDecoration3::BorderSize size)
{
    switch (size) {
    case KDecoration3::BorderSize::None:
        return 0.0;
    case KDecoration3::BorderSize::NoSides:
        return 0.0;
    case KDecoration3::BorderSize::Tiny:
        return 0.5;
    case KDecoration3::BorderSize::Normal:
        return 1.0;
    case KDecoration3::BorderSize::Large:
        return 1.5;
    case KDecoration3::BorderSize::VeryLarge:
        return 2.0;
    case KDecoration3::BorderSize::Huge:
        return 2.5;
    case KDecoration3::BorderSize::VeryHuge:
        return 3.0;
    case KDecoration3::BorderSize::Oversized:
        return 5.0;
    default:
        return 1.0;
    }
}

} // namespace

CdeDecoration::CdeDecoration(QObject *parent, const QVariantList &args)
    : KDecoration3::Decoration(parent, args)
{
}

CdeDecoration::~CdeDecoration()
{
    // Clean up buttons (though Qt parent ownership should handle this)
    qDeleteAll(m_leftButtons);
    qDeleteAll(m_rightButtons);
    m_leftButtons.clear();
    m_rightButtons.clear();
}

bool CdeDecoration::Snapshot::operator==(const Snapshot &other) const
{
    return width == other.width
        && height == other.height
        && active == other.active
        && maximized == other.maximized
        && resizeable == other.resizeable
        && caption == other.caption
        && iconKey == other.iconKey;
}

bool CdeDecoration::init()
{
    loadConfig();
    initializeButtons();
    connectStateSources();
    syncAndRepaint();
    return true;
}

void CdeDecoration::loadConfig()
{
    KConfig config(Config::configFile);
    KConfigGroup group = config.group(Config::groupName);

    m_frameColor = Config::enforceFrameRules(
        group.readEntry(Config::frameColorKey, Config::defaultFrameColor));
    m_activeTitleColor =
        group.readEntry(Config::activeTitleColorKey, Config::defaultActiveTitleColor);
    m_inactiveTitleColor =
        group.readEntry(Config::inactiveTitleColorKey, Config::defaultInactiveTitleColor);
    m_activeTextColor =
        group.readEntry(Config::activeTextColorKey, Config::defaultActiveTextColor);
    m_inactiveTextColor =
        group.readEntry(Config::inactiveTextColorKey, Config::defaultInactiveTextColor);
}

void CdeDecoration::paint(QPainter *painter, const QRectF &repaintArea)
{
    if (!painter) {
        return;
    }

    const Snapshot current = snapshot();
    if (!(current == m_snapshot)) {
        m_snapshot = current;
        recalculateMetrics();
        updateBordersAndTitleBar();
        layoutButtons();
        updateButtonsVisibility();
    }

    painter->save();
    painter->setRenderHint(QPainter::Antialiasing, false);
    paintFrame(painter);
    paintTitleBar(painter);
    paintCaption(painter);
    paintResizeHighlight(painter);
    paintButtons(painter, repaintArea.toAlignedRect());
    painter->restore();
}

QRect CdeDecoration::titleBarRect() const
{
    const QRect full = rect().toAlignedRect();
    return QRect(m_borderWidth,
                 m_borderWidth,
                 std::max(0, full.width() - (m_borderWidth * 2)),
                 m_titleHeight);
}

QRect CdeDecoration::captionRect() const
{
    const QRect bar = titleBarRect();
    int left = bar.x() + m_titlePadding;
    int right = bar.x() + bar.width() - m_titlePadding;

    for (const auto *button : m_leftButtons) {
        if (button->isVisible()) {
            left = std::max(left, button->geometry().toAlignedRect().right() + 1 + m_titlePadding);
        }
    }
    for (const auto *button : m_rightButtons) {
        if (button->isVisible()) {
            right = std::min(right, button->geometry().toAlignedRect().left() - m_titlePadding);
        }
    }

    return QRect(left,
                 bar.y(),
                 std::max(0, right - left),
                 bar.height());
}

QColor CdeDecoration::frameBaseColor() const
{
    return m_frameColor.isValid() ? m_frameColor : Config::defaultFrameColor;
}

QColor CdeDecoration::titleBaseColor() const
{
    auto *w = window();
    if (w && w->isActive()) {
        return m_activeTitleColor.isValid() ? m_activeTitleColor : Config::defaultActiveTitleColor;
    }
    return m_inactiveTitleColor.isValid() ? m_inactiveTitleColor : Config::defaultInactiveTitleColor;
}

QColor CdeDecoration::textColor() const
{
    auto *w = window();
    if (w && w->isActive()) {
        return m_activeTextColor.isValid() ? m_activeTextColor : Config::defaultActiveTextColor;
    }
    return m_inactiveTextColor.isValid() ? m_inactiveTextColor : Config::defaultInactiveTextColor;
}

QColor CdeDecoration::warningColor() const
{
    return m_activeTitleColor.isValid() ? m_activeTitleColor : Config::defaultActiveTitleColor;
}

void CdeDecoration::syncAndRepaint()
{
    loadConfig();
    m_snapshot = snapshot();
    recalculateMetrics();
    updateBordersAndTitleBar();
    layoutButtons();
    updateButtonsVisibility();
    update();
}

void CdeDecoration::initializeButtons()
{
    if (!m_leftButtons.isEmpty() || !m_rightButtons.isEmpty()) {
        return;
    }

    m_leftButtons.append(new CdeButton(KDecoration3::DecorationButtonType::Menu, this, this));

    m_rightButtons.append(new CdeButton(KDecoration3::DecorationButtonType::Minimize, this, this));
    m_rightButtons.append(new CdeButton(KDecoration3::DecorationButtonType::Maximize, this, this));
    m_rightButtons.append(new CdeButton(KDecoration3::DecorationButtonType::Close, this, this));
}

void CdeDecoration::connectStateSources()
{
    // Guard against multiple connection attempts
    if (m_signalsConnected) {
        return;
    }
    m_signalsConnected = true;

    auto *w = window();
    if (w) {
        connect(w, &KDecoration3::DecoratedWindow::activeChanged, this, &CdeDecoration::syncAndRepaint);
        connect(w, &KDecoration3::DecoratedWindow::captionChanged, this, &CdeDecoration::syncAndRepaint);
        connect(w, &KDecoration3::DecoratedWindow::iconChanged, this, &CdeDecoration::syncAndRepaint);
        connect(w, &KDecoration3::DecoratedWindow::widthChanged, this, &CdeDecoration::syncAndRepaint);
        connect(w, &KDecoration3::DecoratedWindow::heightChanged, this, &CdeDecoration::syncAndRepaint);
        connect(w, &KDecoration3::DecoratedWindow::maximizedChanged, this, &CdeDecoration::syncAndRepaint);
        connect(w, &KDecoration3::DecoratedWindow::resizeableChanged, this, &CdeDecoration::syncAndRepaint);
        connect(w, &KDecoration3::DecoratedWindow::closeableChanged, this, &CdeDecoration::syncAndRepaint);
        connect(w, &KDecoration3::DecoratedWindow::minimizeableChanged, this, &CdeDecoration::syncAndRepaint);
        connect(w, &KDecoration3::DecoratedWindow::maximizeableChanged, this, &CdeDecoration::syncAndRepaint);
    }

    if (settings()) {
        connect(settings().get(), &KDecoration3::DecorationSettings::reconfigured, this, &CdeDecoration::syncAndRepaint);
        connect(settings().get(), &KDecoration3::DecorationSettings::fontChanged, this, &CdeDecoration::syncAndRepaint);
        connect(settings().get(), &KDecoration3::DecorationSettings::borderSizeChanged, this, &CdeDecoration::syncAndRepaint);
    }

    connect(this, &KDecoration3::Decoration::sectionUnderMouseChanged, this, [this](Qt::WindowFrameSection) {
        update();
    });
}

void CdeDecoration::recalculateMetrics()
{
    // Calculate border scale based on user's BorderSize setting
    qreal borderScale = 1.0;
    if (settings()) {
        borderScale = borderSizeScale(settings()->borderSize());
    }

    // For None/NoSides, use minimal borders but keep functional
    if (borderScale < 0.5) {
        m_borderWidth = kOuterBevelWidth + kInnerBevelWidth;  // Minimum functional border
        m_resizeOnlyWidth = 2;
    } else {
        m_borderWidth = std::max(kOuterBevelWidth + kInnerBevelWidth + 1,
                                 static_cast<int>(kBaseBorderWidth * borderScale));
        m_resizeOnlyWidth = std::max(2, static_cast<int>(kBaseResizeOnlyWidth * borderScale));
    }

    m_titleHeight = std::max(kBaseTitleHeight, 20);
    m_buttonSpacing = 0;
    m_titlePadding = std::max(4, static_cast<int>(kBaseTitlePadding * borderScale));

    // Scale title height based on font
    if (settings()) {
        const QFontMetrics metrics(settings()->font());
        m_titleHeight = std::max(m_titleHeight, metrics.height() + 4);
    }

    m_buttonSize = m_titleHeight;
}

void CdeDecoration::layoutButtons()
{
    const QRect title = titleBarRect();
    int left = title.x();
    for (auto *button : m_leftButtons) {
        if (!button->isVisible()) {
            continue;
        }
        button->setGeometry(QRectF(left, title.y(), m_buttonSize, m_buttonSize));
        left += m_buttonSize + m_buttonSpacing;
    }

    int right = title.x() + title.width() - m_buttonSize;
    for (auto it = m_rightButtons.rbegin(); it != m_rightButtons.rend(); ++it) {
        auto *button = *it;
        if (!button->isVisible()) {
            continue;
        }
        button->setGeometry(QRectF(right, title.y(), m_buttonSize, m_buttonSize));
        right -= m_buttonSize + m_buttonSpacing;
    }
}

void CdeDecoration::updateBordersAndTitleBar()
{
    // The borders tell KWin how much space the decoration needs.
    // This must account for: outer bevel + frame fill + inner bevel
    // The inner bevel (kInnerBevelWidth) is drawn INSIDE the border area,
    // so we need to ensure m_borderWidth includes space for it.
    setBorders(QMarginsF(m_borderWidth,
                         m_borderWidth + m_titleHeight,
                         m_borderWidth,
                         m_borderWidth));
    setResizeOnlyBorders(QMarginsF(m_resizeOnlyWidth,
                                   m_resizeOnlyWidth,
                                   m_resizeOnlyWidth,
                                   m_resizeOnlyWidth));
    setTitleBar(QRectF(titleBarRect()));
    setOpaque(true);
}

void CdeDecoration::updateButtonsVisibility()
{
    auto *w = window();

    for (auto *button : m_leftButtons) {
        button->setVisible(true);
    }

    for (auto *button : m_rightButtons) {
        if (!w) {
            button->setVisible(true);
            continue;
        }
        switch (button->type()) {
        case KDecoration3::DecorationButtonType::Close:
            button->setVisible(w->isCloseable());
            break;
        case KDecoration3::DecorationButtonType::Minimize:
            button->setVisible(w->isMinimizeable());
            break;
        case KDecoration3::DecorationButtonType::Maximize:
            button->setVisible(w->isMaximizeable());
            break;
        default:
            button->setVisible(true);
            break;
        }
    }
}

void CdeDecoration::paintFrame(QPainter *painter) const
{
    const QRect full = rect().toAlignedRect();
    if (full.isEmpty()) {
        return;
    }

    // Client area is inside the borders
    const QRect clientRect(m_borderWidth,
                           m_borderWidth + m_titleHeight,
                           std::max(0, full.width() - (m_borderWidth * 2)),
                           std::max(0, full.height() - (m_borderWidth * 2) - m_titleHeight));

    // Fill the entire frame area with base color
    const QRegion frameRegion(full);
    const QRegion clientRegion(clientRect);

    painter->save();
    painter->setClipRegion(frameRegion.subtracted(clientRegion));
    painter->fillRect(full, frameBaseColor());
    painter->restore();

    // Draw outer raised bevel on the full decoration rect
    drawBevel(painter, full, frameBaseColor(), false, kOuterBevelWidth);

    // Draw inner sunken bevel around the client area (creates the inset effect)
    // The inner bevel rect is 1 pixel outside the client rect
    const QRect innerBevelRect(clientRect.x() - kInnerBevelWidth,
                               clientRect.y() - kInnerBevelWidth,
                               clientRect.width() + (kInnerBevelWidth * 2),
                               clientRect.height() + (kInnerBevelWidth * 2));
    drawBevel(painter, innerBevelRect, frameBaseColor(), true, kInnerBevelWidth);

    // Draw separator line between titlebar and frame (below titlebar)
    const QColor separatorDark = shade(frameBaseColor(), kBevelDarkPercent);
    const QColor separatorLight = shade(frameBaseColor(), kBevelLightPercent);
    const int sepY = m_borderWidth + m_titleHeight - kInnerBevelWidth - 1;
    const int sepLeft = m_borderWidth;
    const int sepRight = full.width() - m_borderWidth - 1;

    painter->setPen(separatorDark);
    painter->drawLine(sepLeft, sepY, sepRight, sepY);
    painter->setPen(separatorLight);
    painter->drawLine(sepLeft, sepY + 1, sepRight, sepY + 1);
}

void CdeDecoration::paintTitleBar(QPainter *painter) const
{
    const QRect title = titleBarRect();
    if (!title.isEmpty()) {
        drawBevel(painter, title, titleBaseColor(), false, kInnerLineWidth);
    }
}

void CdeDecoration::paintCaption(QPainter *painter) const
{
    const QRect area = captionRect();
    auto *w = window();
    if (area.isEmpty() || !w) {
        return;
    }

    QFont font = settings() ? settings()->font() : painter->font();
    font.setBold(true);
    painter->setFont(font);
    painter->setPen(textColor());

    const QFontMetrics metrics(font);
    const QString caption = metrics.elidedText(w->caption(), Qt::ElideRight, std::max(0, area.width() - m_titlePadding));
    painter->drawText(area.adjusted(m_titlePadding / 2, 0, -m_titlePadding / 2, 0),
                      Qt::AlignVCenter | Qt::AlignLeft,
                      caption);
}

void CdeDecoration::paintButtons(QPainter *painter, const QRect &repaintArea) const
{
    const QRectF repaintAreaF(repaintArea);
    for (CdeButton *button : m_leftButtons) {
        if (button->isVisible() && button->geometry().toAlignedRect().intersects(repaintArea)) {
            button->paint(painter, repaintAreaF);
        }
    }
    for (CdeButton *button : m_rightButtons) {
        if (button->isVisible() && button->geometry().toAlignedRect().intersects(repaintArea)) {
            button->paint(painter, repaintAreaF);
        }
    }
}

void CdeDecoration::paintResizeHighlight(QPainter *painter) const
{
    const auto *w = window();
    if (!w || !w->isResizeable()) {
        return;
    }

    const QColor baseColor = frameBaseColor();

    // Corners and edges use the same base color as the frame — consistent beveling
    const Qt::WindowFrameSection corners[] = {
        Qt::TopLeftSection,
        Qt::TopRightSection,
        Qt::BottomLeftSection,
        Qt::BottomRightSection
    };

    for (const auto &corner : corners) {
        if (!hoverRectForSection(corner).isEmpty()) {
            paintCornerHandle(painter, corner, baseColor);
        }
    }

    const Qt::WindowFrameSection edges[] = { Qt::LeftSection, Qt::RightSection, Qt::TopSection, Qt::BottomSection };
    for (const auto &edge : edges) {
        const QRect r = hoverRectForSection(edge);
        if (!r.isEmpty()) {
            drawBevel(painter, r, baseColor, false, kOuterBevelWidth);
        }
    }
}

void CdeDecoration::paintCornerHandle(QPainter *painter,
                                      Qt::WindowFrameSection section,
                                      const QColor &fill) const
{
    const QRect bounds = hoverRectForSection(section);
    if (bounds.isEmpty()) {
        return;
    }

    const int bw = m_borderWidth;
    const int lw = kOuterBevelWidth;
    const QColor light = shade(fill, kBevelLightPercent);
    const QColor dark = shade(fill, kBevelDarkPercent);

    // Build L-shaped polygon and draw with proper bevels
    // The L has an outer corner and an inner corner
    QPolygon lShape;

    const int x1 = bounds.left();
    const int y1 = bounds.top();
    const int x2 = bounds.right() + 1;
    const int y2 = bounds.bottom() + 1;

    switch (section) {
    case Qt::TopLeftSection:
        // L shape: top-left outer corner
        //   ######
        //   ##
        //   ##
        lShape << QPoint(x1, y1) << QPoint(x2, y1) << QPoint(x2, y1 + bw)
               << QPoint(x1 + bw, y1 + bw) << QPoint(x1 + bw, y2) << QPoint(x1, y2);
        painter->setBrush(fill);
        painter->setPen(Qt::NoPen);
        painter->drawPolygon(lShape);

        // Light edges: outer top, outer left
        painter->fillRect(x1, y1, x2 - x1, lw, light);
        painter->fillRect(x1, y1, lw, y2 - y1, light);
        // Dark edges: inner bottom of horiz arm, inner right of horiz arm, inner right of vert arm, inner bottom of vert arm
        painter->fillRect(x1 + bw, y1 + bw - lw, x2 - x1 - bw, lw, dark);
        painter->fillRect(x2 - lw, y1, lw, bw, dark);
        painter->fillRect(x1 + bw - lw, y1 + bw, lw, y2 - y1 - bw, dark);
        painter->fillRect(x1, y2 - lw, bw, lw, dark);
        break;

    case Qt::TopRightSection:
        // L shape: top-right outer corner
        //   ######
        //       ##
        //       ##
        lShape << QPoint(x1, y1) << QPoint(x2, y1) << QPoint(x2, y2)
               << QPoint(x2 - bw, y2) << QPoint(x2 - bw, y1 + bw) << QPoint(x1, y1 + bw);
        painter->setBrush(fill);
        painter->setPen(Qt::NoPen);
        painter->drawPolygon(lShape);

        // Light edges: outer top, inner left of horiz arm, inner left of vert arm
        painter->fillRect(x1, y1, x2 - x1, lw, light);
        painter->fillRect(x1, y1, lw, bw, light);  // inner left of horiz arm (full height)
        painter->fillRect(x2 - bw, y1 + bw, lw, y2 - y1 - bw, light);  // inner left of vert arm
        // Dark edges: outer right, inner bottom of horiz arm, inner bottom of vert arm
        painter->fillRect(x2 - lw, y1, lw, y2 - y1, dark);
        painter->fillRect(x1 + lw, y1 + bw - lw, x2 - x1 - bw - lw, lw, dark);  // inner bottom of horiz arm
        painter->fillRect(x2 - bw, y2 - lw, bw, lw, dark);  // inner bottom of vert arm
        break;

    case Qt::BottomLeftSection:
        // L shape: bottom-left outer corner
        //   ##
        //   ##
        //   ######
        lShape << QPoint(x1, y1) << QPoint(x1 + bw, y1) << QPoint(x1 + bw, y2 - bw)
               << QPoint(x2, y2 - bw) << QPoint(x2, y2) << QPoint(x1, y2);
        painter->setBrush(fill);
        painter->setPen(Qt::NoPen);
        painter->drawPolygon(lShape);

        // Light edges: outer left, inner top of vert arm, inner top of horiz arm
        painter->fillRect(x1, y1, lw, y2 - y1, light);
        painter->fillRect(x1, y1, bw, lw, light);
        painter->fillRect(x1 + bw, y2 - bw, x2 - x1 - bw, lw, light);
        // Dark edges: outer bottom, inner right of vert arm, inner right of horiz arm
        painter->fillRect(x1, y2 - lw, x2 - x1, lw, dark);
        painter->fillRect(x1 + bw - lw, y1, lw, y2 - y1 - bw, dark);
        painter->fillRect(x2 - lw, y2 - bw, lw, bw, dark);
        break;

    case Qt::BottomRightSection:
        // L shape: bottom-right outer corner
        //       ##
        //       ##
        //   ######
        lShape << QPoint(x2 - bw, y1) << QPoint(x2, y1) << QPoint(x2, y2)
               << QPoint(x1, y2) << QPoint(x1, y2 - bw) << QPoint(x2 - bw, y2 - bw);
        painter->setBrush(fill);
        painter->setPen(Qt::NoPen);
        painter->drawPolygon(lShape);

        // Light edges: inner left of vert arm, inner top of vert arm, inner left of horiz arm, inner top of horiz arm
        painter->fillRect(x2 - bw, y1, lw, y2 - y1 - bw, light);
        painter->fillRect(x2 - bw, y1, bw, lw, light);
        painter->fillRect(x1, y2 - bw, lw, bw, light);
        painter->fillRect(x1, y2 - bw, x2 - x1 - bw, lw, light);
        // Dark edges: outer right, outer bottom
        painter->fillRect(x2 - lw, y1, lw, y2 - y1, dark);
        painter->fillRect(x1, y2 - lw, x2 - x1, lw, dark);
        break;

    default:
        return;
    }
}

void CdeDecoration::drawBevel(QPainter *painter,
                              const QRect &rect,
                              const QColor &fill,
                              bool sunken,
                              int lineWidth) const
{
    if (rect.width() <= 0 || rect.height() <= 0) {
        return;
    }

    const int lw = std::max(1, lineWidth);
    const QColor light = sunken ? shade(fill, kBevelDarkPercent) : shade(fill, kBevelLightPercent);
    const QColor dark = sunken ? shade(fill, kBevelLightPercent) : shade(fill, kBevelDarkPercent);

    // Fill the interior (excluding bevel edges)
    const QRect interior = rect.adjusted(lw, lw, -lw, -lw);
    if (interior.width() > 0 && interior.height() > 0) {
        painter->fillRect(interior, fill);
    }

    // Draw light edges (top and left) as filled polygons for clean corners
    // Top edge: full width band, lw pixels tall
    painter->fillRect(QRect(rect.left(), rect.top(), rect.width(), lw), light);
    // Left edge: from below top band to bottom-lw, lw pixels wide
    painter->fillRect(QRect(rect.left(), rect.top() + lw, lw, rect.height() - lw * 2), light);

    // Draw dark edges (bottom and right) as filled polygons
    // Bottom edge: full width band, lw pixels tall
    painter->fillRect(QRect(rect.left(), rect.bottom() - lw + 1, rect.width(), lw), dark);
    // Right edge: from top to above bottom band, lw pixels wide
    painter->fillRect(QRect(rect.right() - lw + 1, rect.top(), lw, rect.height() - lw), dark);

    // Fix the corners where light and dark meet - draw diagonal separation
    // Bottom-left corner: light above diagonal, dark below
    // Top-right corner: light below diagonal, dark above
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

QRect CdeDecoration::hoverRectForSection(Qt::WindowFrameSection section) const
{
    const QRect full = rect().toAlignedRect();
    const int corner = m_titleHeight + m_borderWidth;
    const int side = std::max(m_resizeOnlyWidth, m_borderWidth);

    switch (section) {
    case Qt::TopLeftSection:
        return QRect(0, 0, corner, corner);
    case Qt::TopRightSection:
        return QRect(full.width() - corner, 0, corner, corner);
    case Qt::BottomLeftSection:
        return QRect(0, full.height() - corner, corner, corner);
    case Qt::BottomRightSection:
        return QRect(full.width() - corner, full.height() - corner, corner, corner);
    case Qt::LeftSection:
        return QRect(0, corner, side, std::max(0, full.height() - corner * 2));
    case Qt::RightSection:
        return QRect(full.width() - side, corner, side, std::max(0, full.height() - corner * 2));
    case Qt::TopSection:
        return QRect(corner, 0, std::max(0, full.width() - corner * 2), side);
    case Qt::BottomSection:
        return QRect(corner, full.height() - side, std::max(0, full.width() - corner * 2), side);
    default:
        return QRect();
    }
}

QColor CdeDecoration::shade(const QColor &base, int percent) const
{
    return scaledShade(base, percent);
}

CdeDecoration::Snapshot CdeDecoration::snapshot() const
{
    Snapshot result;
    auto *w = window();
    if (w) {
        result.width = static_cast<int>(w->width());
        result.height = static_cast<int>(w->height());
        result.active = w->isActive();
        result.maximized = w->isMaximized();
        result.resizeable = w->isResizeable();
        result.caption = w->caption();
        result.iconKey = w->icon().cacheKey();
    }
    return result;
}

} // namespace CdeKWin
