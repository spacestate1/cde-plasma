#pragma once

#include <QColor>
#include <QFont>
#include <QIcon>
#include <QRect>
#include <QString>
#include <QList>

#include <kdecoration3/decoration.h>
#include <kdecoration3/decorationdefines.h>

class QPainter;

namespace CdeKWin
{

class CdeButton;

class CdeDecoration : public KDecoration3::Decoration
{
    Q_OBJECT

public:
    explicit CdeDecoration(QObject *parent, const QVariantList &args);
    ~CdeDecoration() override;

    bool init() override;
    void paint(QPainter *painter, const QRectF &repaintArea) override;

    [[nodiscard]] QRect titleBarRect() const;
    [[nodiscard]] QRect captionRect() const;
    [[nodiscard]] QColor frameBaseColor() const;
    [[nodiscard]] QColor titleBaseColor() const;
    [[nodiscard]] QColor textColor() const;
    [[nodiscard]] QColor warningColor() const;

public Q_SLOTS:
    void syncAndRepaint();

private:
    struct Snapshot {
        int width = 0;
        int height = 0;
        bool active = false;
        bool maximized = false;
        bool resizeable = true;
        QString caption;
        quint64 iconKey = 0;

        bool operator==(const Snapshot &other) const;
    };

    void loadConfig();
    void initializeButtons();
    void connectStateSources();
    void recalculateMetrics();
    void layoutButtons();
    void updateBordersAndTitleBar();
    void updateButtonsVisibility();
    void paintFrame(QPainter *painter) const;
    void paintTitleBar(QPainter *painter) const;
    void paintCaption(QPainter *painter) const;
    void paintButtons(QPainter *painter, const QRect &repaintArea) const;
    void paintResizeHighlight(QPainter *painter) const;
    void paintCornerHandle(QPainter *painter, Qt::WindowFrameSection section, const QColor &fill) const;
    void drawBevel(QPainter *painter, const QRect &rect, const QColor &fill, bool sunken, int lineWidth = 1) const;
    [[nodiscard]] QRect hoverRectForSection(Qt::WindowFrameSection section) const;
    [[nodiscard]] QColor shade(const QColor &base, int percent) const;
    [[nodiscard]] Snapshot snapshot() const;

    Snapshot m_snapshot;
    QList<CdeButton *> m_leftButtons;
    QList<CdeButton *> m_rightButtons;
    bool m_signalsConnected = false;

    int m_borderWidth = 6;
    int m_titleHeight = 28;
    int m_buttonSize = 20;
    int m_buttonSpacing = 0;
    int m_titlePadding = 6;
    int m_resizeOnlyWidth = 6;

    // Cached colors from config
    QColor m_frameColor;
    QColor m_activeTitleColor;
    QColor m_inactiveTitleColor;
    QColor m_activeTextColor;
    QColor m_inactiveTextColor;
};

} // namespace CdeKWin
