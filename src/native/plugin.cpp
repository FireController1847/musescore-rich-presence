#include "discordipc.h"

#include <QQmlExtensionPlugin>
#include <qqml.h>

class DiscordIPCPlugin : public QQmlExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlExtensionInterface_iid)

public:
    void registerTypes(const char *uri) override
    {
        qmlRegisterType<DiscordIPC>(uri, 1, 0, "DiscordClient");
    }
};

#include "plugin.moc"
