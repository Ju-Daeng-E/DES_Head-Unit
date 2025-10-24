#ifndef BACKEND_WEATHER_WEATHER_SERVICE_H
#define BACKEND_WEATHER_WEATHER_SERVICE_H

#include <QObject>
#include <QDateTime>
#include <QNetworkAccessManager>
#include <QtMath>

class QNetworkReply;

class WeatherService : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString condition READ condition NOTIFY conditionChanged)
    Q_PROPERTY(QString icon READ icon NOTIFY iconChanged)
    Q_PROPERTY(double temperature READ temperature NOTIFY temperatureChanged)
    Q_PROPERTY(double humidity READ humidity NOTIFY humidityChanged)
    Q_PROPERTY(double windSpeed READ windSpeed NOTIFY windSpeedChanged)
    Q_PROPERTY(double precipitation READ precipitation NOTIFY precipitationChanged)
    Q_PROPERTY(QDateTime lastUpdated READ lastUpdated NOTIFY lastUpdatedChanged)

public:
    explicit WeatherService(QObject* parent = nullptr);

    QString condition() const;
    QString icon() const;
    double temperature() const;
    double humidity() const;
    double windSpeed() const;
    double precipitation() const;
    QDateTime lastUpdated() const;

    Q_INVOKABLE void fetchWeather();

signals:
    void conditionChanged();
    void iconChanged();
    void temperatureChanged();
    void humidityChanged();
    void windSpeedChanged();
    void precipitationChanged();
    void lastUpdatedChanged();
    void errorOccurred(const QString& message);

private slots:
    void handleWeatherReply();

private:
    void updateFromPayload(const QByteArray& payload);
    QString iconForCode(int code) const;
    QString descriptionForCode(int code) const;

    QNetworkAccessManager manager_;
    QNetworkReply* pendingReply_ = nullptr;

    QString condition_;
    QString icon_;
    double temperature_ = qQNaN();
    double humidity_ = qQNaN();
    double windSpeed_ = qQNaN();
    double precipitation_ = qQNaN();
    QDateTime lastUpdated_;
};

#endif // BACKEND_WEATHER_WEATHER_SERVICE_H
