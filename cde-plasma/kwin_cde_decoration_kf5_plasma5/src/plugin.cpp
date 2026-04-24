#include <KPluginFactory>

#include "cdedecoration.h"
#include "cdedecorationkcm.h"

K_PLUGIN_FACTORY_WITH_JSON(CdeDecorationFactory,
                           "cde_kdecoration.json",
                           registerPlugin<CdeKWin::CdeDecoration>();
                           registerPlugin<CdeDecorationKcm>();)

#include "plugin.moc"
