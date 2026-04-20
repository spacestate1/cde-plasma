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

#include <kdecoration2/decoratedclient.h>
#include <kdecoration2/decorationsettings.h>

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

// Returns a scale factor based on BorderSize setting
// Normal = 1.0, Tiny = 0.5, Large = 1.5, etc.
qreal borderSizeScale(KDecoration2::BorderSize size)
{
    switch (size) {
    case KDecoration2::BorderSize::None:
        return 0.0;
    case KDecoration2::BorderSize::NoSides:
        return 0.0;
    case KDecoration2::BorderSize::Tiny:
        return 0.5;
    case KDecoration2::BorderSize::Normal:
        return 1.0;
    case KDecoration2::BorderSize::Large:
        return 1.5;
    case KDecoration2::BorderSize::VeryLarge:
        return 2.0;
    case KDecoration2::BorderSize::Huge:
        return 2.5;
    case KDecoration2::BorderSize::VeryHuge:
        return 3.0;
    case KDecoration2::BorderSize::Oversized:
        return 5.0;
    default:
        return 1.0;
    }
}

} // namespace

CdeDecoration::CdeDecoration(QObject *parent, const QVariantList &args)
    : KDecoration2::Decoration(parent, args)
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

void CdeDecoration::init()
{
    loadConfig();
    initializeButtons();
    connectStateSources();
    syncAndRepaint();
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

void CdeDecoration::paint(QPainter *painter, const QRect &repaintArea)
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
    paintButtons(painter, repaintArea);
    painter->restore();
}

QRect CdeDecoration::titleBarRect() const
{
    const QRect full = rect();
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
    auto c = client().toStrongRef();
    if (c && c->isActive()) {
        return m_activeTitleColor.isValid() ? m_activeTitleColor : Config::defaultActiveTitleColor;
    }
    return m_inactiveTitleColor.isValid() ? m_inactiveTitleColor : Config::defaultInactiveTitleColor;
}

QColor CdeDecoration::textColor() const
{
    auto c = client().toStrongRef();
    if (c && c->isActive()) {
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

    m_leftButtons.append(new CdeButton(KDecoration2::DecorationButtonType::Menu, this, this));

    m_rightButtons.append(new CdeButton(KDecoration2::DecorationButtonType::Minimize, this, this));
    m_rightButtons.append(new CdeButton(KDecoration2::DecorationButtonType::Maximize, this, this));
    m_rightButtons.append(new CdeButton(KDecoration2::DecorationButtonType::Close, this, this));
}

void CdeDecoration::connectStateSources()
{
    // Guard against multiple connection attempts
    if (m_signalsConnected) {
        return;
    }
    m_signalsConnected = true;

    if (auto c = client().toStrongRef()) {
        connect(c.data(), &KDecoration2::DecoratedClient::activeChanged, this, &CdeDecoration::syncAndRepaint);
        connect(c.data(), &KDecoration2::DecoratedClient::captionChanged, this, &CdeDecoration::syncAndRepaint);
        connect(c.data(), &KDecoration2::DecoratedClient::iconChanged, this, &CdeDecoration::syncAndRepaint);
        connect(c.data(), &KDecoration2::DecoratedClient::widthChanged, this, &CdeDecoration::syncAndRepaint);
        connect(c.data(), &KDecoration2::DecoratedClient::heightChanged, this, &CdeDecoration::syncAndRepaint);
        connect(c.data(), &KDecoration2::DecoratedClient::maximizedChanged, this, &CdeDecoration::syncAndRepaint);
        connect(c.data(), &KDecoration2::DecoratedClient::resizeableChanged, this, &CdeDecoration::syncAndRepaint);
        connect(c.data(), &KDecoration2::DecoratedClient::closeableChanged, this, &CdeDecoration::syncAndRepaint);
        connect(c.data(), &KDecoration2::DecoratedClient::minimizeableChanged, this, &CdeDecoration::syncAndRepaint);
        connect(c.data(), &KDecoration2::DecoratedClient::maximizeableChanged, this, &CdeDecoration::syncAndRepaint);
    }

    if (settings()) {
        connect(settings().data(), &KDecoration2::DecorationSettings::reconfigured, this, &CdeDecoration::syncAndRepaint);
        connect(settings().data(), &KDecoration2::DecorationSettings::fontChanged, this, &CdeDecoration::syncAndRepaint);
        connect(settings().data(), &KDecoration2::DecorationSettings::borderSizeChanged, this, &CdeDecoration::syncAndRepaint);
    }

    connect(this, &KDecoration2::Decoration::sectionUnderMouseChanged, this, [this](Qt::WindowFrameSection) {
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
    setBorders(QMargins(m_borderWidth,
                        m_borderWidth + m_titleHeight,
                        m_borderWidth,
                        m_borderWidth));
    setResizeOnlyBorders(QMargins(m_resizeOnlyWidth,
                                  m_resizeOnlyWidth,
                                  m_resizeOnlyWidth,
                                  m_resizeOnlyWidth));
    setTitleBar(titleBarRect());
    setOpaque(true);
}

void CdeDecoration::updateButtonsVisibility()
{
    auto c = client().toStrongRef();

    for (auto *button : m_leftButtons) {
        button->setVisible(true);
    }

    for (auto *button : m_rightButtons) {
        if (!c) {
            button->setVisible(true);
            continue;
        }
        switch (button->type()) {
        case KDecoration2::DecorationButtonType::Close:
            button->setVisible(c->isCloseable());
            break;
        case KDecoration2::DecorationButtonType::Minimize:
            button->setVisible(c->isMinimizeable());
            break;
        case KDecoration2::DecorationButtonType::Maximize:
            button->setVisible(c->isMaximizeable());
            break;
        default:
            button->setVisible(true);
            break;
        }
    }
}

void CdeDecoration::paintFrame(QPainter *painter) const
{
    const QRect full = rect();
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
    auto c = client().toStrongRef();
    if (area.isEmpty() || !c) {
        return;
    }

    QFont font = settings() ? settings()->font() : painter->font();
    font.setBold(true);
    painter->setFont(font);
    painter->setPen(textColor());

    const QFontMetrics metrics(font);
    const QString caption = metrics.elidedText(c->caption(), Qt::ElideRight, std::max(0, area.width() - m_titlePadding));
    painter->drawText(area.adjusted(m_titlePadding / 2, 0, -m_titlePadding / 2, 0),
                      Qt::AlignVCenter | Qt::AlignLeft,
                      caption);
}

void CdeDecoration::paintButtons(QPainter *painter, const QRect &repaintArea) const
{
    for (CdeButton *button : m_leftButtons) {
        if (button->isVisible() && button->geometry().toAlignedRect().intersects(repaintArea)) {
            button->paint(painter, repaintArea);
        }
    }
    for (CdeButton *button : m_rightButtons) {
        if (button->isVisible() && button->geometry().toAlignedRect().intersects(repaintArea)) {
            button->paint(painter, repaintArea);
        }
    }
}

void CdeDecoration::paintResizeHighlight(QPainter *painter) const
{
    auto c = client().toStrongRef();
    if (!c || !c->isResizeable()) {
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
    QPolygon lShape;

    const int x1 = bounds.left();
    const int y1 = bounds.top();
    const int x2 = bounds.right() + 1;
    const int y2 = bounds.bottom() + 1;

    switch (section) {
    case Qt::TopLeftSection:
        lShape << QPoint(x1, y1) << QPoint(x2, y1) << QPoint(x2, y1 + bw)
               << QPoint(x1 + bw, y1 + bw) << QPoint(x1 + bw, y2) << QPoint(x1, y2);
        painter->setBrush(fill);
        painter->setPen(Qt::NoPen);
        painter->drawPolygon(lShape);

        painter->fillRect(x1, y1, x2 - x1, lw, light);
        painter->fillRect(x1, y1, lw, y2 - y1, light);
        painter->fillRect(x1 + bw, y1 + bw - lw, x2 - x1 - bw, lw, dark);
        painter->fillRect(x2 - lw, y1, lw, bw, dark);
        painter->fillRect(x1 + bw - lw, y1 + bw, lw, y2 - y1 - bw, dark);
        painter->fillRect(x1, y2 - lw, bw, lw, dark);
        break;

    case Qt::TopRightSection:
        lShape << QPoint(x1, y1) << QPoint(x2, y1) << QPoint(x2, y2)
               << QPoint(x2 - bw, y2) << QPoint(x2 - bw, y1 + bw) << QPoint(x1, y1 + bw);
        painter->setBrush(fill);
        painter->setPen(Qt::NoPen);
        painter->drawPolygon(lShape);

        painter->fillRect(x1, y1, x2 - x1, lw, light);
        painter->fillRect(x1, y1, lw, bw, light);
        painter->fillRect(x2 - bw, y1 + bw, lw, y2 - y1 - bw, light);
        painter->fillRect(x2 - lw, y1, lw, y2 - y1, dark);
        painter->fillRect(x1 + lw, y1 + bw - lw, x2 - x1 - bw - lw, lw, dark);
        painter->fillRect(x2 - bw, y2 - lw, bw, lw, dark);
        break;

    case Qt::BottomLeftSection:
        lShape << QPoint(x1, y1) << QPoint(x1 + bw, y1) << QPoint(x1 + bw, y2 - bw)
               << QPoint(x2, y2 - bw) << QPoint(x2, y2) << QPoint(x1, y2);
        painter->setBrush(fill);
        painter->setPen(Qt::NoPen);
        painter->drawPolygon(lShape);

        painter->fillRect(x1, y1, lw, y2 - y1, light);
        painter->fillRect(x1, y1, bw, lw, light);
        painter->fillRect(x1 + bw, y2 - bw, x2 - x1 - bw, lw, light);
        painter->fillRect(x1, y2 - lw, x2 - x1, lw, dark);
        painter->fillRect(x1 + bw - lw, y1, lw, y2 - y1 - bw, dark);
        painter->fillRect(x2 - lw, y2 - bw, lw, bw, dark);
        break;

    case Qt::BottomRightSection:
        lShape << QPoint(x2 - bw, y1) << QPoint(x2, y1) << QPoint(x2, y2)
               << QPoint(x1, y2) << QPoint(x1, y2 - bw) << QPoint(x2 - bw, y2 - bw);
        painter->setBrush(fill);
        painter->setPen(Qt::NoPen);
        painter->drawPolygon(lShape);

        painter->fillRect(x2 - bw, y1, lw, y2 - y1 - bw, light);
        painter->fillRect(x2 - bw, y1, bw, lw, light);
        painter->fillRect(x1, y2 - bw, lw, bw, light);
        painter->fillRect(x1, y2 - bw, x2 - x1 - bw, lw, light);
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

    // Draw light edges (top and left)
    painter->fillRect(QRect(rect.left(), rect.top(), rect.width(), lw), light);
    painter->fillRect(QRect(rect.left(), rect.top() + lw, lw, rect.height() - lw * 2), light);

    // Draw dark edges (bottom and right)
    painter->fillRect(QRect(rect.left(), rect.bottom() - lw + 1, rect.width(), lw), dark);
    painter->fillRect(QRect(rect.right() - lw + 1, rect.top(), lw, rect.height() - lw), dark);

    // Fix the corners where light and dark meet
    for (int i = 0; i < lw; ++i) {
        painter->setPen(light);
        painter->drawLine(rect.left() + i, rect.bottom() - lw + 1,
                          rect.left() + i, rect.bottom() - i);
        painter->drawLine(rect.right() - lw + 1, rect.top() + i,
                          rect.right() - i - 1, rect.top() + i);
    }
}

QRect CdeDecoration::hoverRectForSection(Qt::WindowFrameSection section) const
{
    const QRect full = rect();
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
    if (auto c = client().toStrongRef()) {
        result.width = c->width();
        result.height = c->height();
        result.active = c->isActive();
        result.maximized = c->isMaximized();
        result.resizeable = c->isResizeable();
        result.caption = c->caption();
        result.iconKey = c->icon().cacheKey();
    }
    return result;
}

} // namespace CdeKWin
