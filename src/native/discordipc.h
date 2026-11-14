#pragma once

#include <QByteArray>
#include <QElapsedTimer>
#include <QJsonObject>
#include <QLocalSocket>
#include <QObject>
#include <QStringList>
#include <QTimer>
#include <QVariantMap>

class DiscordIPC : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool ready READ ready NOTIFY readyChanged)

public:
    explicit DiscordIPC(QObject *parent = nullptr);
    ~DiscordIPC() override;

    bool ready() const { return m_ready; }

    Q_INVOKABLE void start(const QString &clientId);
    Q_INVOKABLE void stop();
    Q_INVOKABLE void setActivity(const QVariantMap &activity);

signals:
    void readyChanged();

private:
    void tick();
    void connected();
    void disconnected();
    void receive();
    void setReady(bool ready);
    void sendActivity(const QJsonValue &activity);
    void sendFrame(quint32 opcode, const QByteArray &payload);
    QStringList socketPaths() const;

    QLocalSocket m_socket;
    QTimer m_retry;
    QElapsedTimer m_attempt;
    QByteArray m_buffer;
    QStringList m_paths;
    QString m_clientId;
    QJsonObject m_activity;
    int m_nextPath = 0;
    bool m_enabled = false;
    bool m_ready = false;
    bool m_hasActivity = false;
};
