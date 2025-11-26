#include "HeadUnit.h"

#include <QQmlContext>
#include <QUrl>
#include <QCoreApplication>
#include <QMetaObject>
#include <cstdlib>

HeadUnit::HeadUnit()
    : _engine(std::make_unique<QQmlApplicationEngine>())
    , _musicPlayer(std::make_shared<MusicPlayer>())
    , _gearClient(std::make_shared<GearClient>())
    , _weatherService(std::make_shared<WeatherService>())
    , _bluetoothManager(std::make_shared<BluetoothManager>())
    , _bluetoothAudioPlayer(std::make_shared<BluetoothAudioPlayer>()) {

    // Integrate BluetoothManager with BluetoothAudioPlayer
    _bluetoothManager->setAudioPlayer(_bluetoothAudioPlayer.get());
}

HeadUnit::~HeadUnit() = default;

void HeadUnit::setTimer(const std::string& name) {
    if (_timers.find(name) != _timers.end()) {
        return;
    }

    auto timer = std::make_unique<QTimer>();
    timer->setTimerType(Qt::CoarseTimer);
    _timers.emplace(name, std::move(timer));
}

void HeadUnit::removeTimer(const std::string& name) {
    auto it = _timers.find(name);
    if (it == _timers.end()) {
        return;
    }

    if (it->second) {
        it->second->stop();
    }
    _timers.erase(it);
}

void HeadUnit::connectTimerModel(const std::string& name, int interval, ViewModel& model,
                                 void (ViewModel::*slot)(const std::string&)) {
    if (interval <= 0) {
        return;
    }

    if (_timers.find(name) == _timers.end()) {
        setTimer(name);
    }

    auto& timerPtr = _timers[name];
    if (!timerPtr) {
        return;
    }

    timerPtr->setInterval(interval);
    timerPtr->setSingleShot(false);

    QObject::connect(timerPtr.get(), &QTimer::timeout, &model, [slot, &model, name]() {
        (model.*slot)(name);
    });

    timerPtr->start();
}

void HeadUnit::registerModel(const std::string& name, ViewModel& model) {
    if (!_engine) {
        _engine = std::make_unique<QQmlApplicationEngine>();
    }

    const QString identifier = QString::fromStdString(name);
    _engine->rootContext()->setContextProperty(identifier, &model);
}

void HeadUnit::loadQml(const std::string& path, QGuiApplication& app) {
    if (!_engine) {
        _engine = std::make_unique<QQmlApplicationEngine>();
    }

    _engine->rootContext()->setContextProperty(QStringLiteral("musicPlayer"), _musicPlayer.get());
    _engine->rootContext()->setContextProperty(QStringLiteral("gearClient"), _gearClient.get());
    _engine->rootContext()->setContextProperty(QStringLiteral("weatherService"), _weatherService.get());
    _engine->rootContext()->setContextProperty(QStringLiteral("bluetoothManager"), _bluetoothManager.get());
    _engine->rootContext()->setContextProperty(QStringLiteral("bluetoothAudioPlayer"), _bluetoothAudioPlayer.get());

    if (_weatherService) {
        QMetaObject::invokeMethod(_weatherService.get(), &WeatherService::fetchWeather, Qt::QueuedConnection);
    }

    const QString sourceString = QString::fromStdString(path);
    const QUrl sourceUrl = sourceString.startsWith(QStringLiteral("qrc:/"))
                               ? QUrl(sourceString)
                               : QUrl::fromLocalFile(sourceString);

    QObject::connect(
        _engine.get(), &QQmlApplicationEngine::objectCreated, &app,
        [sourceUrl](QObject* obj, const QUrl& objUrl) {
            if (!obj && sourceUrl == objUrl) {
                QCoreApplication::exit(EXIT_FAILURE);
            }
        },
        Qt::QueuedConnection);

    _engine->load(sourceUrl);
}
