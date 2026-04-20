#include <KPluginFactory>

#include "cdedecoration.h"

K_PLUGIN_FACTORY_WITH_JSON(CdeDecorationFactory,
                           "cde_kdecoration.json",
                           registerPlugin<CdeKWin::CdeDecoration>();)

#include "plugin.moc"
