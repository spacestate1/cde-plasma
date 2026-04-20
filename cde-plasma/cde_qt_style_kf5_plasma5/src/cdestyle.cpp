#include "cdestyle.h"

#include <QPainter>
#include <QPolygon>
#include <QStyleFactory>
#include <QStyleOptionComplex>
#include <QStyleOptionFrame>
#include <QStyleOptionMenuItem>
#include <QStyleOptionProgressBar>
#include <QStyleOptionSlider>

#include <algorithm>

namespace CdeQtStyle
{

namespace
{

constexpr int kFrameWidth = 3;
constexpr int kScrollBarExtent = 18;
constexpr int kScrollBarSpacing = 2;
constexpr int kScrollBarSliderMin = 24;
constexpr int kScrollButtonExtent = 18;
constexpr int kScrollCrossInset = 2;
constexpr int kMenuPanelWidth = 2;
constexpr int kMenuHMargin = 2;
constexpr int kMenuVMargin = 2;
constexpr int kMenuItemVMargin = 3;
constexpr int kMenuItemHMargin = 8;
constexpr int kMenuSeparatorHeight = 8;
constexpr int kMenuArrowWidth = 14;
constexpr int kMenuShortcutGap = 12;
constexpr int kMenuIndicatorMinWidth = 18;

struct ScrollBarRects
{
    QRect subLine;
    QRect addLine;
    QRect groove;
    QRect slider;
    QRect subPage;
    QRect addPage;
};

// CDE Blue-Gray color palette (from KDE 3 CDE theme)
QColor cdeWindowColor()
{
    return QColor(174, 178, 195);  // #AEB2C3 - main background
}

QColor cdeBaseColor()
{
    return QColor(147, 151, 165);  // #9397A5 - window background
}

QColor cdeLightColor()
{
    return QColor(200, 203, 214);  // lighter shade for highlights
}

QColor cdeMidLightColor()
{
    return QColor(187, 190, 204);  // mid-light shade
}

QColor cdeMidColor()
{
    return QColor(138, 142, 155);  // #8A8E9B - alternate background
}

QColor cdeDarkColor()
{
    return QColor(100, 103, 115);  // dark shade for borders
}

QColor cdeShadowColor()
{
    return QColor(60, 62, 70);     // shadow color
}

QColor cdeTextColor()
{
    return QColor(0, 0, 0);        // #000000 - black text
}

QColor cdeHighlightColor()
{
    return QColor(113, 139, 165);  // #718BA5 - selection color
}

QColor disabledTextColor()
{
    return QColor(90, 92, 100);    // disabled text
}

QColor scaledShade(const QColor &base, int percent)
{
    const auto clampChannel = [](int value) {
        return std::clamp(value, 0, 255);
    };

    return QColor(clampChannel(base.red() * percent / 100),
                  clampChannel(base.green() * percent / 100),
                  clampChannel(base.blue() * percent / 100),
                  base.alpha());
}

void drawBevel(QPainter *painter,
               const QRect &rect,
               const QColor &fill,
               const QPalette &palette,
               bool sunken,
               int thickness)
{
    if (!rect.isValid() || thickness <= 0) {
        return;
    }

    const QRect bounds = rect;
    const QColor outerTopLeft = sunken ? palette.shadow().color() : palette.light().color();
    const QColor innerTopLeft = sunken ? palette.dark().color() : palette.midlight().color();
    const QColor outerBottomRight = sunken ? palette.light().color() : palette.shadow().color();
    const QColor innerBottomRight = sunken ? palette.midlight().color() : palette.dark().color();

    painter->fillRect(bounds.adjusted(thickness, thickness, -thickness, -thickness), fill);

    for (int offset = 0; offset < thickness; ++offset) {
        const QColor topLeft = offset == 0 ? outerTopLeft : innerTopLeft;
        const QColor bottomRight = offset == 0 ? outerBottomRight : innerBottomRight;

        painter->setPen(topLeft);
        painter->drawLine(bounds.left() + offset, bounds.top() + offset, bounds.right() - offset, bounds.top() + offset);
        painter->drawLine(bounds.left() + offset, bounds.top() + offset, bounds.left() + offset, bounds.bottom() - offset);

        painter->setPen(bottomRight);
        painter->drawLine(bounds.left() + offset, bounds.bottom() - offset, bounds.right() - offset, bounds.bottom() - offset);
        painter->drawLine(bounds.right() - offset, bounds.top() + offset, bounds.right() - offset, bounds.bottom() - offset);
    }
}

void drawVerticalChannelEdges(QPainter *painter, const QRect &rect, const QPalette &palette)
{
    painter->setPen(palette.light().color());
    painter->drawLine(rect.left(), rect.top(), rect.left(), rect.bottom());
    painter->setPen(palette.dark().color());
    painter->drawLine(rect.right(), rect.top(), rect.right(), rect.bottom());
}

void drawHorizontalChannelEdges(QPainter *painter, const QRect &rect, const QPalette &palette)
{
    painter->setPen(palette.light().color());
    painter->drawLine(rect.left(), rect.top(), rect.right(), rect.top());
    painter->setPen(palette.dark().color());
    painter->drawLine(rect.left(), rect.bottom(), rect.right(), rect.bottom());
}

void drawArrowGlyph(QPainter *painter, const QRect &rect, Qt::ArrowType arrow, const QColor &color, bool pressed)
{
    if (!rect.isValid()) {
        return;
    }

    QRect bounds = rect;
    if (pressed) {
        bounds.translate(1, 1);
    }
    const int span = std::max(6, std::min(bounds.width(), bounds.height()) - 8);
    const int half = span / 2;
    const QPoint center = bounds.center();
    QPolygon polygon;

    switch (arrow) {
    case Qt::UpArrow:
        polygon << QPoint(center.x(), center.y() - half)
                << QPoint(center.x() - half, center.y() + half - 1)
                << QPoint(center.x() + half, center.y() + half - 1);
        break;
    case Qt::DownArrow:
        polygon << QPoint(center.x() - half, center.y() - half)
                << QPoint(center.x() + half, center.y() - half)
                << QPoint(center.x(), center.y() + half);
        break;
    case Qt::LeftArrow:
        polygon << QPoint(center.x() - half, center.y())
                << QPoint(center.x() + half - 1, center.y() - half)
                << QPoint(center.x() + half - 1, center.y() + half);
        break;
    case Qt::RightArrow:
    default:
        polygon << QPoint(center.x() + half, center.y())
                << QPoint(center.x() - half, center.y() - half)
                << QPoint(center.x() - half, center.y() + half);
        break;
    }

    painter->setPen(Qt::NoPen);
    painter->setBrush(color);
    painter->drawPolygon(polygon);
}

ScrollBarRects scrollBarRects(const QStyleOptionSlider *option)
{
    ScrollBarRects rects;
    if (!option) {
        return rects;
    }

    const QRect bounds = option->rect;
    const bool vertical = option->orientation == Qt::Vertical;
    const int availableSpan = vertical ? bounds.height() : bounds.width();
    const int buttonExtent = std::max(0, std::min(kScrollButtonExtent, availableSpan / 2));

    if (vertical) {
        rects.subLine = QRect(bounds.left(), bounds.top(), bounds.width(), buttonExtent);
        rects.addLine = QRect(bounds.left(), bounds.bottom() - buttonExtent + 1, bounds.width(), buttonExtent);
        rects.groove = QRect(bounds.left(),
                             rects.subLine.bottom() + 1,
                             bounds.width(),
                             std::max(0, rects.addLine.top() - rects.subLine.bottom() - 1));
    } else {
        rects.subLine = QRect(bounds.left(), bounds.top(), buttonExtent, bounds.height());
        rects.addLine = QRect(bounds.right() - buttonExtent + 1, bounds.top(), buttonExtent, bounds.height());
        rects.groove = QRect(rects.subLine.right() + 1,
                             bounds.top(),
                             std::max(0, rects.addLine.left() - rects.subLine.right() - 1),
                             bounds.height());
    }

    QRect track = rects.groove;
    if (vertical) {
        const int inset = std::min(kScrollCrossInset, std::max(0, (track.width() - 3) / 2));
        track.adjust(inset, 0, -inset, 0);
    } else {
        const int inset = std::min(kScrollCrossInset, std::max(0, (track.height() - 3) / 2));
        track.adjust(0, inset, 0, -inset);
    }

    const int trackLength = vertical ? track.height() : track.width();
    int sliderLength = trackLength;

    if (trackLength > 0 && option->maximum > option->minimum) {
        const int pageStep = std::max(1, option->pageStep);
        const int totalUnits = option->maximum - option->minimum + pageStep;
        sliderLength = std::max(kScrollBarSliderMin, (pageStep * trackLength) / std::max(1, totalUnits));
        sliderLength = std::min(sliderLength, trackLength);
    }

    int sliderOffset = 0;
    if (trackLength > sliderLength && option->maximum > option->minimum) {
        sliderOffset = QStyle::sliderPositionFromValue(option->minimum,
                                                       option->maximum,
                                                       option->sliderPosition,
                                                       trackLength - sliderLength,
                                                       option->upsideDown);
    }

    if (vertical) {
        rects.slider = QRect(track.left(), track.top() + sliderOffset, track.width(), sliderLength);
        rects.subPage = QRect(rects.groove.left(), rects.groove.top(), rects.groove.width(),
                              std::max(0, rects.slider.top() - rects.groove.top()));
        rects.addPage = QRect(rects.groove.left(), rects.slider.bottom() + 1, rects.groove.width(),
                              std::max(0, rects.groove.bottom() - rects.slider.bottom()));
    } else {
        rects.slider = QRect(track.left() + sliderOffset, track.top(), sliderLength, track.height());
        rects.subPage = QRect(rects.groove.left(), rects.groove.top(),
                              std::max(0, rects.slider.left() - rects.groove.left()), rects.groove.height());
        rects.addPage = QRect(rects.slider.right() + 1, rects.groove.top(),
                              std::max(0, rects.groove.right() - rects.slider.right()), rects.groove.height());
    }

    return rects;
}

bool shouldDrawScrollAreaFrame(const QWidget *widget)
{
    return widget && widget->inherits("QAbstractScrollArea");
}

bool isInteractiveMenuItem(QStyleOptionMenuItem::MenuItemType type)
{
    return type == QStyleOptionMenuItem::Normal
        || type == QStyleOptionMenuItem::DefaultItem
        || type == QStyleOptionMenuItem::SubMenu;
}

QString menuLabelText(const QString &text)
{
    const int tab = text.indexOf(QLatin1Char('\t'));
    return tab >= 0 ? text.left(tab) : text;
}

QString menuShortcutText(const QString &text)
{
    const int tab = text.indexOf(QLatin1Char('\t'));
    return tab >= 0 ? text.mid(tab + 1) : QString();
}

void drawMenuCheckMark(QPainter *painter, const QRect &rect, const QColor &color)
{
    const int left = rect.left() + std::max(2, rect.width() / 5);
    const int midX = rect.left() + rect.width() / 2 - 1;
    const int right = rect.right() - std::max(2, rect.width() / 5);
    const int midY = rect.center().y() + 2;
    const int topY = rect.top() + std::max(2, rect.height() / 4);
    const int bottomY = rect.bottom() - std::max(2, rect.height() / 4);

    QPen pen(color, 2);
    pen.setCapStyle(Qt::SquareCap);
    pen.setJoinStyle(Qt::MiterJoin);
    pen.setCosmetic(true);
    painter->setPen(pen);
    painter->drawLine(QPoint(left, midY), QPoint(midX, bottomY));
    painter->drawLine(QPoint(midX, bottomY), QPoint(right, topY));
}

} // namespace

CdeStyle::CdeStyle()
    : QProxyStyle(QStyleFactory::create(QStringLiteral("Fusion")))
{
}

void CdeStyle::polish(QPalette &palette)
{
    palette = standardPalette();
}

QPalette CdeStyle::standardPalette() const
{
    if (m_paletteBuilt)
        return m_cachedPalette;

    QPalette palette = QProxyStyle::standardPalette();

    const QColor window = cdeWindowColor();
    const QColor base = cdeBaseColor();
    const QColor light = cdeLightColor();
    const QColor midlight = cdeMidLightColor();
    const QColor mid = cdeMidColor();
    const QColor dark = cdeDarkColor();
    const QColor shadow = cdeShadowColor();
    const QColor text = cdeTextColor();
    const QColor disabledText = disabledTextColor();
    const QColor highlight = cdeHighlightColor();

    palette.setColor(QPalette::Active, QPalette::Window, window);
    palette.setColor(QPalette::Active, QPalette::Button, window);
    palette.setColor(QPalette::Active, QPalette::Base, base);
    palette.setColor(QPalette::Active, QPalette::AlternateBase, light);
    palette.setColor(QPalette::Active, QPalette::Light, light);
    palette.setColor(QPalette::Active, QPalette::Midlight, midlight);
    palette.setColor(QPalette::Active, QPalette::Mid, mid);
    palette.setColor(QPalette::Active, QPalette::Dark, dark);
    palette.setColor(QPalette::Active, QPalette::Shadow, shadow);
    palette.setColor(QPalette::Active, QPalette::Text, text);
    palette.setColor(QPalette::Active, QPalette::WindowText, text);
    palette.setColor(QPalette::Active, QPalette::ButtonText, text);
    palette.setColor(QPalette::Active, QPalette::BrightText, QColor(255, 255, 255));
    palette.setColor(QPalette::Active, QPalette::Highlight, highlight);
    palette.setColor(QPalette::Active, QPalette::HighlightedText, QColor(255, 255, 255));

    palette.setColor(QPalette::Inactive, QPalette::Window, window);
    palette.setColor(QPalette::Inactive, QPalette::Button, window);
    palette.setColor(QPalette::Inactive, QPalette::Base, base);
    palette.setColor(QPalette::Inactive, QPalette::AlternateBase, light);
    palette.setColor(QPalette::Inactive, QPalette::Light, light);
    palette.setColor(QPalette::Inactive, QPalette::Midlight, midlight);
    palette.setColor(QPalette::Inactive, QPalette::Mid, mid);
    palette.setColor(QPalette::Inactive, QPalette::Dark, dark);
    palette.setColor(QPalette::Inactive, QPalette::Shadow, shadow);
    palette.setColor(QPalette::Inactive, QPalette::Text, text);
    palette.setColor(QPalette::Inactive, QPalette::WindowText, text);
    palette.setColor(QPalette::Inactive, QPalette::ButtonText, text);
    palette.setColor(QPalette::Inactive, QPalette::BrightText, QColor(255, 255, 255));
    palette.setColor(QPalette::Inactive, QPalette::Highlight, highlight);
    palette.setColor(QPalette::Inactive, QPalette::HighlightedText, QColor(255, 255, 255));

    palette.setColor(QPalette::Disabled, QPalette::Window, window);
    palette.setColor(QPalette::Disabled, QPalette::Button, window);
    palette.setColor(QPalette::Disabled, QPalette::Base, base);
    palette.setColor(QPalette::Disabled, QPalette::AlternateBase, light);
    palette.setColor(QPalette::Disabled, QPalette::Light, light);
    palette.setColor(QPalette::Disabled, QPalette::Midlight, midlight);
    palette.setColor(QPalette::Disabled, QPalette::Mid, mid);
    palette.setColor(QPalette::Disabled, QPalette::Dark, dark);
    palette.setColor(QPalette::Disabled, QPalette::Shadow, shadow);
    palette.setColor(QPalette::Disabled, QPalette::Text, disabledText);
    palette.setColor(QPalette::Disabled, QPalette::WindowText, disabledText);
    palette.setColor(QPalette::Disabled, QPalette::ButtonText, disabledText);
    palette.setColor(QPalette::Disabled, QPalette::BrightText, QColor(245, 245, 245));
    palette.setColor(QPalette::Disabled, QPalette::Highlight, mid);
    palette.setColor(QPalette::Disabled, QPalette::HighlightedText, QColor(245, 245, 245));

    palette.setColor(QPalette::ToolTipBase, base);
    palette.setColor(QPalette::ToolTipText, text);

    m_cachedPalette = palette;
    m_paletteBuilt = true;
    return palette;
}

int CdeStyle::pixelMetric(PixelMetric metric, const QStyleOption *option, const QWidget *widget) const
{
    switch (metric) {
    case PM_DefaultFrameWidth:
        return kFrameWidth;
    case PM_MenuPanelWidth:
        return kMenuPanelWidth;
    case PM_MenuHMargin:
        return kMenuHMargin;
    case PM_MenuVMargin:
        return kMenuVMargin;
    case PM_MenuDesktopFrameWidth:
        return 0;
    case PM_ScrollBarExtent:
        return kScrollBarExtent;
    case PM_ScrollBarSliderMin:
        return kScrollBarSliderMin;
    case PM_ScrollView_ScrollBarSpacing:
        return kScrollBarSpacing;
    default:
        return QProxyStyle::pixelMetric(metric, option, widget);
    }
}

QRect CdeStyle::subElementRect(SubElement element, const QStyleOption *option, const QWidget *widget) const
{
    if (element == SE_ShapedFrameContents && shouldDrawScrollAreaFrame(widget) && option) {
        return option->rect.adjusted(kFrameWidth, kFrameWidth, -kFrameWidth, -kFrameWidth);
    }
    if (element == SE_LineEditContents && option) {
        return option->rect.adjusted(kFrameWidth, kFrameWidth, -kFrameWidth, -kFrameWidth);
    }

    return QProxyStyle::subElementRect(element, option, widget);
}

QRect CdeStyle::subControlRect(ComplexControl control,
                               const QStyleOptionComplex *option,
                               SubControl subControl,
                               const QWidget *widget) const
{
    if (control != CC_ScrollBar) {
        return QProxyStyle::subControlRect(control, option, subControl, widget);
    }

    const auto *slider = qstyleoption_cast<const QStyleOptionSlider *>(option);
    if (!slider) {
        return QRect();
    }

    const ScrollBarRects rects = scrollBarRects(slider);
    switch (subControl) {
    case SC_ScrollBarSubLine:
        return rects.subLine;
    case SC_ScrollBarAddLine:
        return rects.addLine;
    case SC_ScrollBarGroove:
        return rects.groove;
    case SC_ScrollBarSlider:
        return rects.slider;
    case SC_ScrollBarSubPage:
        return rects.subPage;
    case SC_ScrollBarAddPage:
        return rects.addPage;
    default:
        return QRect();
    }
}

QSize CdeStyle::sizeFromContents(ContentsType type,
                                 const QStyleOption *option,
                                 const QSize &contentsSize,
                                 const QWidget *widget) const
{
    if (type == CT_MenuItem) {
        const auto *menuItem = qstyleoption_cast<const QStyleOptionMenuItem *>(option);
        if (!menuItem) {
            return QProxyStyle::sizeFromContents(type, option, contentsSize, widget);
        }

        if (menuItem->menuItemType == QStyleOptionMenuItem::Separator) {
            return QSize(contentsSize.width(), kMenuSeparatorHeight + (kMenuVMargin * 2));
        }

        const int indicatorWidth = std::max(kMenuIndicatorMinWidth, menuItem->maxIconWidth) + kMenuItemHMargin;
        const int shortcutWidth = menuItem->tabWidth > 0 ? menuItem->tabWidth + kMenuShortcutGap : 0;
        const int arrowWidth = menuItem->menuItemType == QStyleOptionMenuItem::SubMenu ? kMenuArrowWidth + kMenuItemHMargin : 0;
        const int height = std::max(menuItem->fontMetrics.height() + (kMenuItemVMargin * 2),
                                    18 + (kMenuVMargin * 2));
        const int width = contentsSize.width()
            + indicatorWidth
            + shortcutWidth
            + arrowWidth
            + (kMenuPanelWidth * 2)
            + (kMenuHMargin * 2)
            + (kMenuItemHMargin * 2);
        return QSize(width, height);
    }

    return QProxyStyle::sizeFromContents(type, option, contentsSize, widget);
}

QStyle::SubControl CdeStyle::hitTestComplexControl(ComplexControl control,
                                                   const QStyleOptionComplex *option,
                                                   const QPoint &point,
                                                   const QWidget *widget) const
{
    if (control != CC_ScrollBar) {
        return QProxyStyle::hitTestComplexControl(control, option, point, widget);
    }

    const auto *slider = qstyleoption_cast<const QStyleOptionSlider *>(option);
    if (!slider) {
        return SC_None;
    }

    const ScrollBarRects rects = scrollBarRects(slider);
    if (rects.subLine.contains(point)) {
        return SC_ScrollBarSubLine;
    }
    if (rects.addLine.contains(point)) {
        return SC_ScrollBarAddLine;
    }
    if (rects.slider.contains(point)) {
        return SC_ScrollBarSlider;
    }
    if (rects.subPage.contains(point)) {
        return SC_ScrollBarSubPage;
    }
    if (rects.addPage.contains(point)) {
        return SC_ScrollBarAddPage;
    }
    if (rects.groove.contains(point)) {
        return SC_ScrollBarGroove;
    }
    return SC_None;
}

void CdeStyle::drawPrimitive(PrimitiveElement element,
                             const QStyleOption *option,
                             QPainter *painter,
                             const QWidget *widget) const
{
    if (!option || !painter) {
        return;
    }

    switch (element) {
    case PE_FrameMenu:
    case PE_PanelMenu:
        drawBevel(painter, option->rect, option->palette.button().color(), option->palette, false, kMenuPanelWidth);
        return;
    case PE_PanelLineEdit:
    case PE_FrameLineEdit:
        drawBevel(painter, option->rect, option->palette.base().color(), option->palette, true, kFrameWidth);
        return;
    case PE_PanelScrollAreaCorner:
        painter->fillRect(option->rect, option->palette.midlight().color());
        drawVerticalChannelEdges(painter, option->rect, option->palette);
        drawHorizontalChannelEdges(painter, option->rect, option->palette);
        return;
    case PE_Frame:
        if (shouldDrawScrollAreaFrame(widget)) {
            drawBevel(painter, option->rect, option->palette.base().color(), option->palette, true, kFrameWidth);
            return;
        }
        break;
    default:
        break;
    }

    QProxyStyle::drawPrimitive(element, option, painter, widget);
}

void CdeStyle::drawControl(ControlElement element,
                           const QStyleOption *option,
                           QPainter *painter,
                           const QWidget *widget) const
{
    if (element == CE_MenuEmptyArea) {
        if (!option || !painter) {
            return;
        }
        painter->fillRect(option->rect, option->palette.button().color());
        return;
    }

    if (element == CE_MenuItem) {
        const auto *menuItem = qstyleoption_cast<const QStyleOptionMenuItem *>(option);
        if (!menuItem || !painter) {
            return;
        }

        const QRect rect = menuItem->rect;
        const QRect innerRect = rect.adjusted(kMenuPanelWidth + kMenuHMargin,
                                              kMenuVMargin,
                                              -(kMenuPanelWidth + kMenuHMargin),
                                              -kMenuVMargin);

        if (menuItem->menuItemType == QStyleOptionMenuItem::Separator) {
            const int y = rect.center().y();
            painter->setPen(menuItem->palette.dark().color());
            painter->drawLine(innerRect.left(), y, innerRect.right(), y);
            painter->setPen(menuItem->palette.light().color());
            painter->drawLine(innerRect.left(), y + 1, innerRect.right(), y + 1);
            return;
        }

        const bool enabled = menuItem->state & State_Enabled;
        const bool selected = enabled && (menuItem->state & State_Selected) && isInteractiveMenuItem(menuItem->menuItemType);
        const QColor background = selected ? menuItem->palette.highlight().color() : menuItem->palette.button().color();
        const QColor textColor = selected ? menuItem->palette.highlightedText().color()
                                          : (enabled ? menuItem->palette.buttonText().color()
                                                     : menuItem->palette.color(QPalette::Disabled, QPalette::ButtonText));

        painter->fillRect(rect, menuItem->palette.button().color());
        if (selected) {
            painter->fillRect(innerRect, background);
        }

        const int indicatorWidth = std::max(kMenuIndicatorMinWidth, menuItem->maxIconWidth);
        const QRect indicatorRect(innerRect.left(),
                                  innerRect.top(),
                                  indicatorWidth,
                                  innerRect.height());

        if (menuItem->checked) {
            drawBevel(painter,
                      indicatorRect.adjusted(1, 1, -1, -1),
                      selected ? scaledShade(background, 84) : menuItem->palette.midlight().color(),
                      menuItem->palette,
                      menuItem->checkType != QStyleOptionMenuItem::NotCheckable,
                      1);
        }

        if (!menuItem->icon.isNull()) {
            const QSize iconSize(16, 16);
            const QIcon::Mode mode = enabled ? (selected ? QIcon::Active : QIcon::Normal) : QIcon::Disabled;
            const QPixmap pixmap = menuItem->icon.pixmap(iconSize, mode);
            const QRect pixmapRect(indicatorRect.left() + (indicatorRect.width() - pixmap.width()) / 2,
                                   indicatorRect.top() + (indicatorRect.height() - pixmap.height()) / 2,
                                   pixmap.width(),
                                   pixmap.height());
            painter->drawPixmap(pixmapRect.topLeft(), pixmap);
        } else if (menuItem->checked) {
            drawMenuCheckMark(painter, indicatorRect.adjusted(2, 2, -2, -2), textColor);
        }

        const QRect rightEdgeRect(innerRect.right() - kMenuArrowWidth - kMenuItemHMargin + 1,
                                  innerRect.top(),
                                  kMenuArrowWidth + kMenuItemHMargin,
                                  innerRect.height());
        const int shortcutWidth = menuItem->tabWidth > 0 ? menuItem->tabWidth + kMenuShortcutGap : 0;
        const int arrowSpace = menuItem->menuItemType == QStyleOptionMenuItem::SubMenu ? rightEdgeRect.width() : 0;
        const QRect textRect(indicatorRect.right() + kMenuItemHMargin,
                             innerRect.top(),
                             std::max(0, innerRect.width() - indicatorRect.width() - shortcutWidth - arrowSpace - (kMenuItemHMargin * 2)),
                             innerRect.height());
        const QRect shortcutRect(textRect.right() + 1,
                                 innerRect.top(),
                                 std::max(0, shortcutWidth),
                                 innerRect.height());

        painter->save();
        painter->setFont(menuItem->font);
        painter->setPen(textColor);
        painter->drawText(textRect, Qt::AlignVCenter | Qt::AlignLeft | Qt::TextShowMnemonic | Qt::TextSingleLine,
                          menuLabelText(menuItem->text));
        if (menuItem->tabWidth > 0) {
            painter->drawText(shortcutRect.adjusted(0, 0, -kMenuShortcutGap, 0),
                              Qt::AlignVCenter | Qt::AlignRight | Qt::TextSingleLine,
                              menuShortcutText(menuItem->text));
        }
        painter->restore();

        if (menuItem->menuItemType == QStyleOptionMenuItem::SubMenu) {
            drawArrowGlyph(painter,
                           rightEdgeRect.adjusted(kMenuItemHMargin / 2, 2, -2, -2),
                           Qt::RightArrow,
                           textColor,
                           false);
        }

        return;
    }

    if (element == CE_ProgressBarGroove) {
        if (!option || !painter) {
            return;
        }
        drawBevel(painter, option->rect, option->palette.mid().color(), option->palette, true, 1);
        return;
    }

    if (element == CE_ProgressBarContents) {
        const auto *pb = qstyleoption_cast<const QStyleOptionProgressBar *>(option);
        if (!pb || !painter) {
            return;
        }
        if (pb->progress <= pb->minimum) {
            return;
        }
        const QRect groove = pb->rect.adjusted(1, 1, -1, -1);
        const int range = pb->maximum - pb->minimum;
        const int filled = range > 0
            ? static_cast<int>(static_cast<qint64>(groove.width()) * (pb->progress - pb->minimum) / range)
            : groove.width();
        if (filled > 0) {
            const QRect bar(groove.left(), groove.top(), filled, groove.height());
            painter->fillRect(bar, pb->palette.highlight().color());
        }
        return;
    }

    if (element == CE_ProgressBarLabel) {
        const auto *pb = qstyleoption_cast<const QStyleOptionProgressBar *>(option);
        if (!pb || !painter || pb->text.isEmpty()) {
            return;
        }
        painter->save();
        painter->setPen(pb->palette.buttonText().color());
        painter->drawText(pb->rect, Qt::AlignCenter | Qt::TextSingleLine, pb->text);
        painter->restore();
        return;
    }

    if (element == CE_ShapedFrame && option && painter && shouldDrawScrollAreaFrame(widget)) {
        drawBevel(painter, option->rect, option->palette.base().color(), option->palette, true, kFrameWidth);
        return;
    }

    QProxyStyle::drawControl(element, option, painter, widget);
}

void CdeStyle::drawComplexControl(ComplexControl control,
                                  const QStyleOptionComplex *option,
                                  QPainter *painter,
                                  const QWidget *widget) const
{
    if (control != CC_ScrollBar || !option || !painter) {
        QProxyStyle::drawComplexControl(control, option, painter, widget);
        return;
    }

    const auto *slider = qstyleoption_cast<const QStyleOptionSlider *>(option);
    if (!slider) {
        QProxyStyle::drawComplexControl(control, option, painter, widget);
        return;
    }

    const ScrollBarRects rects = scrollBarRects(slider);
    const bool vertical = slider->orientation == Qt::Vertical;

    const bool subLinePressed = (slider->activeSubControls & SC_ScrollBarSubLine) && (slider->state & State_Sunken);
    const bool addLinePressed = (slider->activeSubControls & SC_ScrollBarAddLine) && (slider->state & State_Sunken);
    const bool sliderPressed = (slider->activeSubControls & SC_ScrollBarSlider) && (slider->state & State_Sunken);

    const QColor buttonFill = slider->palette.button().color();
    const QColor pressedFill = slider->palette.mid().color();
    const QColor troughFill = slider->palette.midlight().color();
    const QColor glyphColor = (slider->state & State_Enabled) ? slider->palette.buttonText().color()
                                                              : slider->palette.color(QPalette::Disabled, QPalette::ButtonText);

    painter->fillRect(option->rect, troughFill);
    if (vertical) {
        drawVerticalChannelEdges(painter, option->rect, slider->palette);
    } else {
        drawHorizontalChannelEdges(painter, option->rect, slider->palette);
    }

    if (rects.groove.isValid()) {
        painter->fillRect(rects.groove, troughFill);
    }

    if (rects.subLine.isValid()) {
        drawBevel(painter, rects.subLine, subLinePressed ? pressedFill : buttonFill, slider->palette, subLinePressed, 1);
        drawArrowGlyph(painter, rects.subLine, vertical ? Qt::UpArrow : Qt::LeftArrow, glyphColor, subLinePressed);
    }

    if (rects.addLine.isValid()) {
        drawBevel(painter, rects.addLine, addLinePressed ? pressedFill : buttonFill, slider->palette, addLinePressed, 1);
        drawArrowGlyph(painter, rects.addLine, vertical ? Qt::DownArrow : Qt::RightArrow, glyphColor, addLinePressed);
    }

    if (rects.slider.isValid()) {
        drawBevel(painter, rects.slider, sliderPressed ? pressedFill : buttonFill, slider->palette, sliderPressed, 2);
    }
}

} // namespace CdeQtStyle
