#pragma once

#include <KCModule>

class KColorButton;

class CdeDecorationKcm : public KCModule
{
    Q_OBJECT

public:
    explicit CdeDecorationKcm(QObject *parent, const KPluginMetaData &data);

    void load() override;
    void save() override;
    void defaults() override;

private:
    void updateChanged();

    KColorButton *m_frameColor;
    KColorButton *m_activeTitleColor;
    KColorButton *m_inactiveTitleColor;
    KColorButton *m_activeTextColor;
    KColorButton *m_inactiveTextColor;
};
