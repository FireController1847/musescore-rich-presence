#include "discordipc.h"

#include <QCoreApplication>
#include <QDir>
#include <QFileInfo>
#ifdef Q_OS_MACOS
#include <unistd.h>
#endif
#include <QJsonDocument>
#include <QJsonValue>
#include <QUuid>
#include <QtEndian>
#include <QDebug>
#include <QGuiApplication>
#include <QQuickWindow>
#include <QQmlComponent>
#include <QQmlContext>
#include <QQmlEngine>
#include <QAbstractItemModel>
#include <QTime>

namespace {
constexpr quint32 Handshake = 0;
constexpr quint32 Frame = 1;
constexpr quint32 Close = 2;
constexpr quint32 Ping = 3;
constexpr quint32 Pong = 4;
constexpr quint32 MaxPayload = 1024 * 1024;

QByteArray encode(const QJsonObject &object)
{
    return QJsonDocument(object).toJson(QJsonDocument::Compact);
}
}

DiscordIPC::DiscordIPC(QObject *parent) : QObject(parent)
{
    const QVariantMap defaults {
        {QStringLiteral("filename"), false},
        {QStringLiteral("title"), true},
        {QStringLiteral("subtitle"), true},
        {QStringLiteral("composer"), true},
        {QStringLiteral("measures"), true},
        {QStringLiteral("pages"), true},
        {QStringLiteral("tracks"), true},
        {QStringLiteral("elapsed"), true},
        {QStringLiteral("playback"), true},
        {QStringLiteral("hideWithoutScore"), true},
        {QStringLiteral("rotation"), 5}
    };
    for (auto it = defaults.cbegin(); it != defaults.cend(); ++it) {
        const QVariant stored = m_settings.value(it.key(), it.value());
        m_preferences.insert(it.key(), it.key() == QStringLiteral("rotation")
            ? QVariant(qBound(5, stored.toInt(), 60)) : QVariant(stored.toBool()));
    }

    m_retry.setInterval(1000);
    connect(&m_retry, &QTimer::timeout, this, &DiscordIPC::tick);
    connect(&m_socket, &QLocalSocket::connected, this, &DiscordIPC::connected);
    connect(&m_socket, &QLocalSocket::disconnected, this, &DiscordIPC::disconnected);
    connect(&m_socket, &QLocalSocket::readyRead, this, &DiscordIPC::receive);
    connect(&m_socket, &QLocalSocket::errorOccurred, this, [this](QLocalSocket::LocalSocketError) {
        if (m_enabled)
            setStatus(QStringLiteral("IPC error: %1 (%2)").arg(m_socket.errorString(), m_currentPath));
    });
}

DiscordIPC::~DiscordIPC()
{
    m_uiRefresh.stop();
    if (m_settingsWindow)
        delete m_settingsWindow.data();
    for (const auto &item : m_statusItems) {
        if (item)
            delete item.data();
    }
    stop();
}

void DiscordIPC::setPreference(const QString &key, const QVariant &value)
{
    if (!m_preferences.contains(key))
        return;
    const QVariant next = key == QStringLiteral("rotation")
        ? QVariant(qBound(5, value.toInt(), 60)) : QVariant(value.toBool());
    if (m_preferences.value(key) == next)
        return;
    m_preferences.insert(key, next);
    m_settings.setValue(key, next);
    emit preferencesChanged();
}

QVariantMap DiscordIPC::playbackSnapshot() const
{
    // MuseScore 4.7 changes the play action icon according to its
    // playback controller. Read the model rather than localized labels.
    constexpr int PlayIcon = 0xEF1D;
    constexpr int PauseIcon = 0xF3C9;
    for (QWindow *window : QGuiApplication::allWindows()) {
        auto *quick = qobject_cast<QQuickWindow *>(window);
        if (!quick || !quick->isVisible())
            continue;
        QList<QQuickItem *> pending{quick->contentItem()};
        while (!pending.isEmpty()) {
            QQuickItem *item = pending.takeLast();
            if (!item)
                continue;
            pending.append(item->childItems());
            if (!QByteArray(item->metaObject()->className()).startsWith("PlaybackToolBarActions"))
                continue;
            auto *model = qobject_cast<QAbstractItemModel *>(
                item->property("playbackModel").value<QObject *>());
            if (!model || !model->property("isPlayAllowed").toBool())
                continue;
            const int role = model->roleNames().key("item", -1);
            if (role < 0)
                continue;
            for (int row = 0; row < model->rowCount(); ++row) {
                QObject *action = model->data(model->index(row, 0), role).value<QObject *>();
                if (!action || action->property("code").toString() != QStringLiteral("play"))
                    continue;
                const int icon = action->property("icon").toInt();
                if (icon != PlayIcon && icon != PauseIcon)
                    continue;
                const QTime time = model->property("playTime").toTime();
                const QTime max = model->property("maxPlayTime").toTime();
                return {
                    {QStringLiteral("known"), true},
                    {QStringLiteral("playing"), icon == PauseIcon},
                    {QStringLiteral("position"), time.isValid() ? QTime(0, 0).msecsTo(time) : -1},
                    {QStringLiteral("duration"), max.isValid() ? QTime(0, 0).msecsTo(max) : -1}
                };
            }
        }
    }
    return {{QStringLiteral("known"), false}};
}

void DiscordIPC::openSettings()
{
    if (auto *window = qobject_cast<QQuickWindow *>(m_settingsWindow.data())) {
        window->show();
        window->raise();
        window->requestActivate();
        return;
    }

    // Use the host UI engine when available for its existing theme.
    QQmlEngine *engine = nullptr;
    for (const auto &item : m_statusItems) {
        if (item && qmlEngine(item.data())) {
            engine = qmlEngine(item.data());
            break;
        }
    }
    if (!engine)
        engine = qobject_cast<QQmlEngine *>(parent());
    if (!engine)
        return;
    QQmlComponent component(engine, QUrl(QStringLiteral("qrc:/discordpresence/SettingsWindow.qml")));
    if (!component.isReady()) {
        qWarning().noquote() << "MuseScore Rich Presence: settings:" << component.errorString();
        return;
    }
    auto *context = new QQmlContext(engine->rootContext(), this);
    context->setContextProperty(QStringLiteral("presenceClient"), this);
    QObject *object = component.create(context);
    auto *window = qobject_cast<QQuickWindow *>(object);
    if (!window) {
        qWarning().noquote() << "MuseScore Rich Presence: settings:" << component.errorString();
        delete object;
        delete context;
        return;
    }
    QQmlEngine::setObjectOwnership(window, QQmlEngine::CppOwnership);
    window->QObject::setParent(this);
    context->setParent(window);
    m_settingsWindow = window;
    window->show();
    window->raise();
    window->requestActivate();
}

bool DiscordIPC::statusBarAvailable() const
{
    for (const auto &item : m_statusItems) {
        if (item && item->isVisible())
            return true;
    }
    return false;
}

bool DiscordIPC::initializeMonitor(const QString &clientId)
{
    if (m_monitorInitialized)
        return false;

    m_monitorInitialized = true;
    m_clientId = clientId;
    connect(&m_uiRefresh, &QTimer::timeout, this, &DiscordIPC::refreshStatusBars);
    m_uiRefresh.start(1000);
    refreshStatusBars();
    return true;
}

void DiscordIPC::toggle()
{
    if (m_enabled)
        stop();
    else
        start(m_clientId);
}

void DiscordIPC::refreshStatusBars()
{
    for (int i = m_statusItems.size() - 1; i >= 0; --i) {
        if (!m_statusItems.at(i))
            m_statusItems.removeAt(i);
    }
    for (QWindow *window : QGuiApplication::allWindows()) {
        auto *quickWindow = qobject_cast<QQuickWindow *>(window);
        if (quickWindow && quickWindow->isVisible())
            attachStatusBar(quickWindow->contentItem());
    }
}

void DiscordIPC::attachStatusBar(QQuickItem *item)
{
    if (!item)
        return;

    // MuseScore 4's notation bar contains a RowLayout for its controls.
    // Restrict insertion to that component, not arbitrary layouts.
    QObject *section = item->property("navigationSection").value<QObject *>();
    const bool isStatusBar =
        QByteArray(item->metaObject()->className()).startsWith("NotationStatusBar")
        || (section && section->property("name").toString() == QStringLiteral("NotationStatusBar"));

    if (isStatusBar) {
        for (QQuickItem *row : item->childItems()) {
            if (!row->inherits("QQuickRowLayout"))
                continue;
            if (row->property("_discordPresenceAttached").toBool())
                return;

            QQmlEngine *engine = qmlEngine(row);
            if (!engine)
                return;

            row->setProperty("_discordPresenceAttached", true);
            QQmlComponent component(engine, QUrl(QStringLiteral("qrc:/discordpresence/StatusButton.qml")));
            if (!component.isReady()) {
                qWarning().noquote() << "MuseScore Rich Presence: status bar:" << component.errorString();
                return;
            }

            auto *context = new QQmlContext(qmlContext(row) ? qmlContext(row) : engine->rootContext(), row);
            context->setContextProperty(QStringLiteral("presenceClient"), this);
            QObject *object = component.create(context);
            auto *button = qobject_cast<QQuickItem *>(object);
            if (!button) {
                qWarning().noquote() << "MuseScore Rich Presence: status bar:" << component.errorString();
                delete object;
                delete context;
                return;
            }

            QQmlEngine::setObjectOwnership(button, QQmlEngine::CppOwnership);
            button->setParent(row);
            button->setParentItem(row);
            context->setParent(button);
            m_statusItems.append(QPointer<QQuickItem>(button));
            qInfo() << "MuseScore Rich Presence: attached notation status icon";
            return;
        }
    }

    for (QQuickItem *child : item->childItems())
        attachStatusBar(child);
}

QStringList DiscordIPC::socketPaths() const
{
    QStringList paths;
#ifdef Q_OS_WIN
    for (int i = 0; i < 10; ++i)
        paths << QStringLiteral("discord-ipc-%1").arg(i);
#else
    QStringList dirs;
    for (const char *name : {"XDG_RUNTIME_DIR", "TMPDIR", "TMP", "TEMP"}) {
        const QString dir = qEnvironmentVariable(name);
        if (!dir.isEmpty())
            dirs << dir;
    }
#ifdef Q_OS_MACOS
    char userTemp[4096];
    const size_t size = confstr(_CS_DARWIN_USER_TEMP_DIR, userTemp, sizeof(userTemp));
    if (size > 0 && size <= sizeof(userTemp))
        dirs << QString::fromLocal8Bit(userTemp);
#endif
    dirs << QDir::tempPath() << QStringLiteral("/tmp");
    dirs.removeDuplicates();

    for (const QString &dir : dirs) {
        for (int i = 0; i < 10; ++i)
            paths << QDir(dir).filePath(QStringLiteral("discord-ipc-%1").arg(i));
    }
#endif
    return paths;
}

void DiscordIPC::start(const QString &clientId)
{
    if (m_enabled && m_clientId == clientId)
        return;

    stop();
    m_socket.abort();
    m_clientId = clientId;
    m_paths = socketPaths();
    m_nextPath = 0;
    m_enabled = true;
    emit enabledChanged();
    setStatus(QStringLiteral("Searching for Discord Desktop"));
    qInfo() << "MuseScore Rich Presence: IPC candidates" << m_paths;
    m_retry.start();
    tick();
}

void DiscordIPC::stop()
{
    const bool wasEnabled = m_enabled;
    m_enabled = false;
    m_retry.stop();

    if (m_ready && m_socket.state() == QLocalSocket::ConnectedState) {
        sendActivity(QJsonValue(QJsonValue::Null));
        m_socket.flush();
        m_socket.disconnectFromServer();
    } else {
        m_socket.abort();
    }

    setReady(false);
    m_buffer.clear();
    m_hasActivity = false;
    m_activity = QJsonObject();
    setStatus(QStringLiteral("Disabled"));
    if (wasEnabled)
        emit enabledChanged();
}

void DiscordIPC::tick()
{
    if (!m_enabled || m_paths.isEmpty())
        return;

    if (m_socket.state() != QLocalSocket::UnconnectedState) {
        // A stale socket or a Discord client that never answers must not
        // prevent subsequent candidates from being tried.
        if (!m_ready && m_attempt.isValid() && m_attempt.elapsed() > 5000)
            m_socket.abort();
        return;
    }

    m_buffer.clear();
    // On Unix, skip nonexistent paths immediately rather than taking up
    // to a minute to reach the actual socket.
    m_paths = socketPaths();
    if (m_paths.isEmpty())
        return;
    m_nextPath %= m_paths.size();
    for (int i = 0; i < m_paths.size(); ++i) {
        const QString path = m_paths.at(m_nextPath);
        m_nextPath = (m_nextPath + 1) % m_paths.size();
#ifndef Q_OS_WIN
        if (!QFileInfo::exists(path))
            continue;
#endif
        m_currentPath = path;
        setStatus(QStringLiteral("Connecting to %1").arg(path));
        m_attempt.restart();
        m_socket.connectToServer(path, QIODevice::ReadWrite);
        return;
    }
    setStatus(QStringLiteral("Waiting for Discord Desktop (no IPC socket found)"));
}

void DiscordIPC::connected()
{
    if (!m_enabled) {
        m_socket.abort();
        return;
    }

    m_attempt.restart();
    setStatus(QStringLiteral("Connected to socket; waiting for Discord handshake"));
    sendFrame(Handshake, encode({
        {QStringLiteral("v"), 1},
        {QStringLiteral("client_id"), m_clientId}
    }));
}

void DiscordIPC::disconnected()
{
    setReady(false);
    m_buffer.clear();
    if (m_enabled)
        setStatus(QStringLiteral("Discord disconnected; reconnecting"));
}

void DiscordIPC::setStatus(const QString &status)
{
    if (m_status == status)
        return;
    m_status = status;
    qInfo().noquote() << "MuseScore Rich Presence:" << status;
    emit statusChanged();
}

void DiscordIPC::setReady(bool ready)
{
    if (m_ready == ready)
        return;
    m_ready = ready;
    emit readyChanged();
}

void DiscordIPC::setActivity(const QVariantMap &activity)
{
    const QJsonObject next = QJsonObject::fromVariantMap(activity);
    if (m_hasActivity && m_activity == next)
        return;

    m_activity = next;
    m_hasActivity = true;

    if (m_ready)
        sendActivity(m_activity);
}

void DiscordIPC::clearActivity()
{
    if (!m_hasActivity)
        return;

    m_hasActivity = false;
    m_activity = QJsonObject();
    if (m_ready) {
        sendActivity(QJsonValue(QJsonValue::Null));
        setStatus(QStringLiteral("Waiting for an open score"));
    }
}

void DiscordIPC::sendActivity(const QJsonValue &activity)
{
    const QJsonObject args {
        {QStringLiteral("pid"), static_cast<double>(QCoreApplication::applicationPid())},
        {QStringLiteral("activity"), activity}
    };
    sendFrame(Frame, encode({
        {QStringLiteral("cmd"), QStringLiteral("SET_ACTIVITY")},
        {QStringLiteral("args"), args},
        {QStringLiteral("nonce"), QUuid::createUuid().toString(QUuid::WithoutBraces)}
    }));
}

void DiscordIPC::sendFrame(quint32 opcode, const QByteArray &payload)
{
    if (m_socket.state() != QLocalSocket::ConnectedState)
        return;

    QByteArray packet(8, '\0');
    qToLittleEndian<quint32>(opcode, packet.data());
    qToLittleEndian<quint32>(static_cast<quint32>(payload.size()), packet.data() + 4);
    packet.append(payload);
    if (m_socket.write(packet) != packet.size()) {
        setStatus(QStringLiteral("Failed to write Discord IPC packet"));
        m_socket.abort();
    } else {
        m_socket.flush();
    }
}

void DiscordIPC::receive()
{
    m_buffer.append(m_socket.readAll());
    while (m_buffer.size() >= 8) {
        const quint32 opcode = qFromLittleEndian<quint32>(m_buffer.constData());
        const quint32 length = qFromLittleEndian<quint32>(m_buffer.constData() + 4);
        if (length > MaxPayload) {
            qWarning() << "MuseScore Rich Presence: oversized IPC frame";
            m_socket.abort();
            m_buffer.clear();
            return;
        }

        const int packetSize = 8 + static_cast<int>(length);
        if (m_buffer.size() < packetSize)
            return;

        const QByteArray payload = m_buffer.mid(8, static_cast<int>(length));
        m_buffer.remove(0, packetSize);

        if (opcode == Ping) {
            sendFrame(Pong, payload);
        } else if (opcode == Close) {
            qWarning() << "MuseScore Rich Presence: Discord closed IPC:" << payload;
            m_socket.abort();
            return;
        } else if (opcode == Frame) {
            const QJsonObject message = QJsonDocument::fromJson(payload).object();
            const QString event = message.value(QStringLiteral("evt")).toString();
            if (event == QStringLiteral("READY") && m_enabled && !m_ready) {
                // Retry this same candidate first if Discord restarts.
                m_nextPath = (m_nextPath + m_paths.size() - 1) % m_paths.size();
                setReady(true);
                if (m_hasActivity) {
                    setStatus(QStringLiteral("Discord handshake accepted; publishing activity"));
                    sendActivity(m_activity);
                } else {
                    setStatus(QStringLiteral("Waiting for an open score"));
                }
            } else if (event == QStringLiteral("ERROR")) {
                setStatus(QStringLiteral("Discord RPC error: %1").arg(
                    message.value(QStringLiteral("data")).toObject()
                           .value(QStringLiteral("message")).toString()));
            } else if (message.value(QStringLiteral("cmd")).toString() == QStringLiteral("SET_ACTIVITY")
                       && m_enabled && m_ready) {
                setStatus(m_hasActivity ? QStringLiteral("Discord accepted activity")
                                        : QStringLiteral("Waiting for an open score"));
            }
        }
    }
}
