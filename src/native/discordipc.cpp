#include "discordipc.h"

#include <QCoreApplication>
#include <QDir>
#include <QJsonDocument>
#include <QJsonValue>
#include <QUuid>
#include <QtEndian>
#include <QDebug>

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
    m_retry.setInterval(1000);
    connect(&m_retry, &QTimer::timeout, this, &DiscordIPC::tick);
    connect(&m_socket, &QLocalSocket::connected, this, &DiscordIPC::connected);
    connect(&m_socket, &QLocalSocket::disconnected, this, &DiscordIPC::disconnected);
    connect(&m_socket, &QLocalSocket::readyRead, this, &DiscordIPC::receive);
}

DiscordIPC::~DiscordIPC()
{
    stop();
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
    dirs << QStringLiteral("/tmp");
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
    m_retry.start();
    tick();
}

void DiscordIPC::stop()
{
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
    const QString path = m_paths.at(m_nextPath);
    m_nextPath = (m_nextPath + 1) % m_paths.size();
    m_attempt.restart();
    m_socket.connectToServer(path, QIODevice::ReadWrite);
}

void DiscordIPC::connected()
{
    if (!m_enabled) {
        m_socket.abort();
        return;
    }

    m_attempt.restart();
    sendFrame(Handshake, encode({
        {QStringLiteral("v"), 1},
        {QStringLiteral("client_id"), m_clientId}
    }));
}

void DiscordIPC::disconnected()
{
    setReady(false);
    m_buffer.clear();
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
    m_socket.write(packet);
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
            qWarning() << "MuseScore Rich Presence: Discord closed the IPC connection";
            m_socket.abort();
            return;
        } else if (opcode == Frame) {
            const QJsonObject message = QJsonDocument::fromJson(payload).object();
            const QString event = message.value(QStringLiteral("evt")).toString();
            if (event == QStringLiteral("READY") && m_enabled && !m_ready) {
                // Retry this same candidate first if Discord restarts.
                m_nextPath = (m_nextPath + m_paths.size() - 1) % m_paths.size();
                setReady(true);
                if (m_hasActivity)
                    sendActivity(m_activity);
            } else if (event == QStringLiteral("ERROR")) {
                qWarning() << "MuseScore Rich Presence: Discord RPC error"
                           << message.value(QStringLiteral("data")).toObject()
                                  .value(QStringLiteral("message")).toString();
            }
        }
    }
}
