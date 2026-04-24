#include "cdedecorationkcm.h"
#include "cdeconfig.h"

#include <KColorButton>
#include <KConfig>
#include <KConfigGroup>
#include <KPluginFactory>

#include <QFormLayout>
#include <QHBoxLayout>
#include <QLabel>
#include <QPushButton>
#include <QVBoxLayout>

using namespace CdeKWin;

CdeDecorationKcm::CdeDecorationKcm(QObject *parent, const KPluginMetaData &data)
    : KCModule(parent, data)
{
    auto *layout = new QVBoxLayout(widget());
    auto *form = new QFormLayout;

    m_frameColor = new KColorButton(widget());
    m_activeTitleColor = new KColorButton(widget());
    m_inactiveTitleColor = new KColorButton(widget());
    m_activeTextColor = new KColorButton(widget());
    m_inactiveTextColor = new KColorButton(widget());

    auto *presetRow = new QHBoxLayout;
    auto *lightButton = new QPushButton(QStringLiteral("Light"), widget());
    auto *darkButton = new QPushButton(QStringLiteral("Dark"), widget());
    auto *chartreuseButton = new QPushButton(QStringLiteral("Chartreuse"), widget());
    auto *electricButton = new QPushButton(QStringLiteral("Electric Pink"), widget());
    presetRow->addWidget(lightButton);
    presetRow->addWidget(darkButton);
    presetRow->addWidget(chartreuseButton);
    presetRow->addWidget(electricButton);
    presetRow->addStretch();
    form->addRow(QStringLiteral("Preset:"), presetRow);

    form->addRow(QStringLiteral("Frame Border Color:"), m_frameColor);
    form->addRow(QStringLiteral("Active Title Color:"), m_activeTitleColor);
    form->addRow(QStringLiteral("Inactive Title Color:"), m_inactiveTitleColor);
    form->addRow(QStringLiteral("Active Text Color:"), m_activeTextColor);
    form->addRow(QStringLiteral("Inactive Text Color:"), m_inactiveTextColor);

    layout->addLayout(form);
    layout->addStretch();

    auto connectButton = [this](KColorButton *btn) {
        connect(btn, &KColorButton::changed, this, &CdeDecorationKcm::updateChanged);
    };
    connectButton(m_frameColor);
    connectButton(m_activeTitleColor);
    connectButton(m_inactiveTitleColor);
    connectButton(m_activeTextColor);
    connectButton(m_inactiveTextColor);

    connect(lightButton, &QPushButton::clicked, this, &CdeDecorationKcm::applyLightPreset);
    connect(darkButton, &QPushButton::clicked, this, &CdeDecorationKcm::applyDarkPreset);
    connect(chartreuseButton, &QPushButton::clicked, this, &CdeDecorationKcm::applyChartreusePreset);
    connect(electricButton, &QPushButton::clicked, this, &CdeDecorationKcm::applyElectricPreset);

    load();
}

void CdeDecorationKcm::load()
{
    KConfig config(Config::configFile);
    KConfigGroup group = config.group(Config::groupName);

    m_frameColor->setColor(Config::enforceFrameRules(
        group.readEntry(Config::frameColorKey, Config::defaultFrameColor)));
    m_activeTitleColor->setColor(
        group.readEntry(Config::activeTitleColorKey, Config::defaultActiveTitleColor));
    m_inactiveTitleColor->setColor(
        group.readEntry(Config::inactiveTitleColorKey, Config::defaultInactiveTitleColor));
    m_activeTextColor->setColor(
        group.readEntry(Config::activeTextColorKey, Config::defaultActiveTextColor));
    m_inactiveTextColor->setColor(
        group.readEntry(Config::inactiveTextColorKey, Config::defaultInactiveTextColor));

    setNeedsSave(false);
}

void CdeDecorationKcm::save()
{
    KConfig config(Config::configFile);
    KConfigGroup group = config.group(Config::groupName);

    group.writeEntry(Config::frameColorKey, Config::enforceFrameRules(m_frameColor->color()));
    group.writeEntry(Config::activeTitleColorKey, m_activeTitleColor->color());
    group.writeEntry(Config::inactiveTitleColorKey, m_inactiveTitleColor->color());
    group.writeEntry(Config::activeTextColorKey, m_activeTextColor->color());
    group.writeEntry(Config::inactiveTextColorKey, m_inactiveTextColor->color());

    config.sync();
    setNeedsSave(false);
}

void CdeDecorationKcm::defaults()
{
    applyLightPreset();
}

void CdeDecorationKcm::applyLightPreset()
{
    m_frameColor->setColor(Config::defaultFrameColor);
    m_activeTitleColor->setColor(Config::defaultActiveTitleColor);
    m_inactiveTitleColor->setColor(Config::defaultInactiveTitleColor);
    m_activeTextColor->setColor(Config::defaultActiveTextColor);
    m_inactiveTextColor->setColor(Config::defaultInactiveTextColor);
    updateChanged();
}

void CdeDecorationKcm::applyDarkPreset()
{
    m_frameColor->setColor(Config::darkFrameColor);
    m_activeTitleColor->setColor(Config::darkActiveTitleColor);
    m_inactiveTitleColor->setColor(Config::darkInactiveTitleColor);
    m_activeTextColor->setColor(Config::darkActiveTextColor);
    m_inactiveTextColor->setColor(Config::darkInactiveTextColor);
    updateChanged();
}

void CdeDecorationKcm::applyChartreusePreset()
{
    m_frameColor->setColor(Config::chartreuseFrameColor);
    m_activeTitleColor->setColor(Config::chartreuseActiveTitleColor);
    m_inactiveTitleColor->setColor(Config::chartreuseInactiveTitleColor);
    m_activeTextColor->setColor(Config::chartreuseActiveTextColor);
    m_inactiveTextColor->setColor(Config::chartreuseInactiveTextColor);
    updateChanged();
}

void CdeDecorationKcm::applyElectricPreset()
{
    m_frameColor->setColor(Config::electricFrameColor);
    m_activeTitleColor->setColor(Config::electricActiveTitleColor);
    m_inactiveTitleColor->setColor(Config::electricInactiveTitleColor);
    m_activeTextColor->setColor(Config::electricActiveTextColor);
    m_inactiveTextColor->setColor(Config::electricInactiveTextColor);
    updateChanged();
}

void CdeDecorationKcm::updateChanged()
{
    setNeedsSave(true);
}

K_PLUGIN_CLASS_WITH_JSON(CdeDecorationKcm, "cde_kdecoration_kcm.json")

#include "cdedecorationkcm.moc"
