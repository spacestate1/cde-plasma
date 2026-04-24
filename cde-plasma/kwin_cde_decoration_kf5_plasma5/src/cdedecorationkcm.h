#pragma once

#include <KCModule>

class KColorButton;

class CdeDecorationKcm : public KCModule
{
    Q_OBJECT

public:
    explicit CdeDecorationKcm(QWidget *parent = nullptr, const QVariantList &args = {});

    void load() override;
    void save() override;
    void defaults() override;

private Q_SLOTS:
    void applyLightPreset();
    void applyDarkPreset();
    void applyChartreusePreset();
    void applyElectricPreset();

private:
    void updateChanged();

    KColorButton *m_frameColor;
    KColorButton *m_activeTitleColor;
    KColorButton *m_inactiveTitleColor;
    KColorButton *m_activeTextColor;
    KColorButton *m_inactiveTextColor;
};
