#include "cdestyle.h"

#include <QStylePlugin>

using namespace CdeQtStyle;

class CdeStylePlugin final : public QStylePlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QStyleFactoryInterface_iid FILE "cde_qt_style.json")

public:
    QStyle *create(const QString &key) override
    {
        const QString normalized = key.trimmed().toLower();
        if (normalized == QLatin1String("cde")) {
            return new CdeStyle();
        }
        return nullptr;
    }
};

#include "plugin.moc"
