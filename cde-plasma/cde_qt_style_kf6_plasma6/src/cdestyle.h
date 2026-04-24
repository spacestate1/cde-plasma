#pragma once

#include <QProxyStyle>

namespace CdeQtStyle
{

class CdeStyle final : public QProxyStyle
{
    Q_OBJECT

public:
    CdeStyle();
    ~CdeStyle() override = default;

    void polish(QPalette &palette) override;
    QPalette standardPalette() const override;

private:
    mutable QPalette m_cachedPalette;
    mutable bool m_paletteBuilt = false;

    int pixelMetric(PixelMetric metric,
                    const QStyleOption *option = nullptr,
                    const QWidget *widget = nullptr) const override;

    QRect subElementRect(SubElement element,
                         const QStyleOption *option,
                         const QWidget *widget = nullptr) const override;

    QRect subControlRect(ComplexControl control,
                         const QStyleOptionComplex *option,
                         SubControl subControl,
                         const QWidget *widget = nullptr) const override;

    QSize sizeFromContents(ContentsType type,
                           const QStyleOption *option,
                           const QSize &contentsSize,
                           const QWidget *widget = nullptr) const override;

    SubControl hitTestComplexControl(ComplexControl control,
                                     const QStyleOptionComplex *option,
                                     const QPoint &point,
                                     const QWidget *widget = nullptr) const override;

    void drawPrimitive(PrimitiveElement element,
                       const QStyleOption *option,
                       QPainter *painter,
                       const QWidget *widget = nullptr) const override;

    void drawControl(ControlElement element,
                     const QStyleOption *option,
                     QPainter *painter,
                     const QWidget *widget = nullptr) const override;

    void drawComplexControl(ComplexControl control,
                            const QStyleOptionComplex *option,
                            QPainter *painter,
                            const QWidget *widget = nullptr) const override;
};

} // namespace CdeQtStyle
