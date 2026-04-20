#pragma once

#include <kdecoration2/decorationbutton.h>

class QPainter;
class QRect;

namespace CdeKWin
{

class CdeDecoration;

class CdeButton : public KDecoration2::DecorationButton
{
    Q_OBJECT

public:
    explicit CdeButton(KDecoration2::DecorationButtonType type, KDecoration2::Decoration *decoration, QObject *parent = nullptr);

    void paint(QPainter *painter, const QRect &repaintArea) override;

private:
    [[nodiscard]] CdeDecoration *cdeDecoration() const;
    void paintMenuGlyph(QPainter *painter, const QRect &rect) const;
    void paintMinimizeGlyph(QPainter *painter, const QRect &rect) const;
    void paintMaximizeGlyph(QPainter *painter, const QRect &rect) const;
    void paintCloseGlyph(QPainter *painter, const QRect &rect) const;
};

} // namespace CdeKWin
