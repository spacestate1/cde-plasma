#pragma once

#include <kdecoration3/decorationbutton.h>

class QPainter;
class QRect;

namespace CdeKWin
{

class CdeDecoration;

class CdeButton : public KDecoration3::DecorationButton
{
    Q_OBJECT

public:
    explicit CdeButton(KDecoration3::DecorationButtonType type, KDecoration3::Decoration *decoration, QObject *parent = nullptr);

    void paint(QPainter *painter, const QRectF &repaintArea) override;

private:
    [[nodiscard]] CdeDecoration *cdeDecoration() const;
    void paintMenuGlyph(QPainter *painter, const QRect &rect) const;
    void paintMinimizeGlyph(QPainter *painter, const QRect &rect) const;
    void paintMaximizeGlyph(QPainter *painter, const QRect &rect) const;
    void paintCloseGlyph(QPainter *painter, const QRect &rect) const;
};

} // namespace CdeKWin
