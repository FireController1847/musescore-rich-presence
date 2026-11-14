#include "discordipc.h"

#include <QQmlExtensionPlugin>
#include <qqml.h>
#include <QQmlEngine>
#include <QJSEngine>
#include <QDebug>

class DiscordIPCPlugin : public QQmlExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlExtensionInterface_iid)

public:
    void registerTypes(const char *uri) override
    {
        qInfo() << "MuseScore Rich Presence: native QML module loaded" << uri;
        qmlRegisterSingletonType<DiscordIPC>(uri, 1, 0, "DiscordClient",
            [](QQmlEngine *engine, QJSEngine *) -> QObject * {
                return new DiscordIPC(engine);
            });
    }
};

#include "plugin.moc"
