#pragma once

#include <QByteArray>
#include <QElapsedTimer>
#include <QJsonObject>
#include <QLocalSocket>
#include <QObject>
#include <QStringList>
#include <QTimer>
#include <QVariantMap>
#include <QList>
#include <QPointer>
#include <QQuickItem>
#include <QSettings>

class DiscordIPC : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool ready READ ready NOTIFY readyChanged)
    Q_PROPERTY(bool enabled READ enabled NOTIFY enabledChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(bool statusBarAvailable READ statusBarAvailable)
    Q_PROPERTY(QVariantMap preferences READ preferences NOTIFY preferencesChanged)

public:
    explicit DiscordIPC(QObject *parent = nullptr);
    ~DiscordIPC() override;

    bool ready() const { return m_ready; }
    bool enabled() const { return m_enabled; }
    QString status() const { return m_status; }

    bool statusBarAvailable() const;
    QVariantMap preferences() const { return m_preferences; }
    Q_INVOKABLE void setPreference(const QString &key, const QVariant &value);
    Q_INVOKABLE QVariantMap playbackSnapshot() const;
    Q_INVOKABLE void openSettings();
    Q_INVOKABLE bool initializeMonitor(const QString &clientId);
    Q_INVOKABLE void start(const QString &clientId);
    Q_INVOKABLE void stop();
    Q_INVOKABLE void toggle();
    Q_INVOKABLE void setActivity(const QVariantMap &activity);
    Q_INVOKABLE void clearActivity();

signals:
    void readyChanged();
    void enabledChanged();
    void statusChanged();
    void preferencesChanged();

private:
    void tick();
    void connected();
    void disconnected();
    void receive();
    void setReady(bool ready);
    void setStatus(const QString &status);
    void refreshStatusBars();
    void attachStatusBar(QQuickItem *item);
    void sendActivity(const QJsonValue &activity);
    void sendFrame(quint32 opcode, const QByteArray &payload);
    QStringList socketPaths() const;

    QLocalSocket m_socket;
    QTimer m_retry;
    QElapsedTimer m_attempt;
    QByteArray m_buffer;
    QStringList m_paths;
    QString m_clientId;
    QString m_status = QStringLiteral("Disabled");
    QString m_currentPath;
    QJsonObject m_activity;
    int m_nextPath = 0;
    bool m_enabled = false;
    bool m_ready = false;
    bool m_hasActivity = false;
    bool m_monitorInitialized = false;
    QTimer m_uiRefresh;
    QVariantMap m_preferences;
    QSettings m_settings{QStringLiteral("MuseScoreRichPresence"), QStringLiteral("Preferences")};
    QPointer<QObject> m_settingsWindow;
    QList<QPointer<QQuickItem>> m_statusItems;
};
