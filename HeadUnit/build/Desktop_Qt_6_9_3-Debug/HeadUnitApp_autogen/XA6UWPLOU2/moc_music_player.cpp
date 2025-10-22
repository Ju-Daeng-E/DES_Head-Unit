/****************************************************************************
** Meta object code from reading C++ file 'music_player.h'
**
** Created by: The Qt Meta Object Compiler version 69 (Qt 6.9.3)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../../../../src/backend/music/music_player.h"
#include <QtCore/qmetatype.h>

#include <QtCore/qtmochelpers.h>

#include <memory>


#include <QtCore/qxptype_traits.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'music_player.h' doesn't include <QObject>."
#elif Q_MOC_OUTPUT_REVISION != 69
#error "This file was generated using the moc from 6.9.3. It"
#error "cannot be used with the include files from this version of Qt."
#error "(The moc has changed too much.)"
#endif

#ifndef Q_CONSTINIT
#define Q_CONSTINIT
#endif

QT_WARNING_PUSH
QT_WARNING_DISABLE_DEPRECATED
QT_WARNING_DISABLE_GCC("-Wuseless-cast")
namespace {
struct qt_meta_tag_ZN11MusicPlayerE_t {};
} // unnamed namespace

template <> constexpr inline auto MusicPlayer::qt_create_metaobjectdata<qt_meta_tag_ZN11MusicPlayerE_t>()
{
    namespace QMC = QtMocConstants;
    QtMocHelpers::StringRefStorage qt_stringData {
        "MusicPlayer",
        "tracksChanged",
        "",
        "currentTrackChanged",
        "playingChanged",
        "durationChanged",
        "positionChanged",
        "progressChanged",
        "playbackError",
        "message",
        "handleStateChanged",
        "QMediaPlayer::PlaybackState",
        "state",
        "handleErrorOccurred",
        "QMediaPlayer::Error",
        "error",
        "errorString",
        "handleDurationChanged",
        "duration",
        "handlePositionChanged",
        "position",
        "handleMediaStatusChanged",
        "QMediaPlayer::MediaStatus",
        "status",
        "loadLibrary",
        "path",
        "play",
        "track",
        "pause",
        "toggle",
        "next",
        "previous",
        "tracks",
        "currentTrack",
        "playing",
        "progress"
    };

    QtMocHelpers::UintData qt_methods {
        // Signal 'tracksChanged'
        QtMocHelpers::SignalData<void()>(1, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'currentTrackChanged'
        QtMocHelpers::SignalData<void()>(3, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'playingChanged'
        QtMocHelpers::SignalData<void()>(4, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'durationChanged'
        QtMocHelpers::SignalData<void()>(5, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'positionChanged'
        QtMocHelpers::SignalData<void()>(6, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'progressChanged'
        QtMocHelpers::SignalData<void()>(7, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'playbackError'
        QtMocHelpers::SignalData<void(const QString &)>(8, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 9 },
        }}),
        // Slot 'handleStateChanged'
        QtMocHelpers::SlotData<void(QMediaPlayer::PlaybackState)>(10, 2, QMC::AccessPrivate, QMetaType::Void, {{
            { 0x80000000 | 11, 12 },
        }}),
        // Slot 'handleErrorOccurred'
        QtMocHelpers::SlotData<void(QMediaPlayer::Error, const QString &)>(13, 2, QMC::AccessPrivate, QMetaType::Void, {{
            { 0x80000000 | 14, 15 }, { QMetaType::QString, 16 },
        }}),
        // Slot 'handleDurationChanged'
        QtMocHelpers::SlotData<void(qint64)>(17, 2, QMC::AccessPrivate, QMetaType::Void, {{
            { QMetaType::LongLong, 18 },
        }}),
        // Slot 'handlePositionChanged'
        QtMocHelpers::SlotData<void(qint64)>(19, 2, QMC::AccessPrivate, QMetaType::Void, {{
            { QMetaType::LongLong, 20 },
        }}),
        // Slot 'handleMediaStatusChanged'
        QtMocHelpers::SlotData<void(QMediaPlayer::MediaStatus)>(21, 2, QMC::AccessPrivate, QMetaType::Void, {{
            { 0x80000000 | 22, 23 },
        }}),
        // Method 'loadLibrary'
        QtMocHelpers::MethodData<void(const QString &)>(24, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 25 },
        }}),
        // Method 'loadLibrary'
        QtMocHelpers::MethodData<void()>(24, 2, QMC::AccessPublic | QMC::MethodCloned, QMetaType::Void),
        // Method 'play'
        QtMocHelpers::MethodData<void(const QString &)>(26, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 27 },
        }}),
        // Method 'play'
        QtMocHelpers::MethodData<void()>(26, 2, QMC::AccessPublic | QMC::MethodCloned, QMetaType::Void),
        // Method 'pause'
        QtMocHelpers::MethodData<void()>(28, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'toggle'
        QtMocHelpers::MethodData<void(const QString &)>(29, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 27 },
        }}),
        // Method 'next'
        QtMocHelpers::MethodData<void()>(30, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'previous'
        QtMocHelpers::MethodData<void()>(31, 2, QMC::AccessPublic, QMetaType::Void),
    };
    QtMocHelpers::UintData qt_properties {
        // property 'tracks'
        QtMocHelpers::PropertyData<QStringList>(32, QMetaType::QStringList, QMC::DefaultPropertyFlags, 0),
        // property 'currentTrack'
        QtMocHelpers::PropertyData<QString>(33, QMetaType::QString, QMC::DefaultPropertyFlags, 1),
        // property 'playing'
        QtMocHelpers::PropertyData<bool>(34, QMetaType::Bool, QMC::DefaultPropertyFlags, 2),
        // property 'duration'
        QtMocHelpers::PropertyData<qint64>(18, QMetaType::LongLong, QMC::DefaultPropertyFlags, 3),
        // property 'position'
        QtMocHelpers::PropertyData<qint64>(20, QMetaType::LongLong, QMC::DefaultPropertyFlags, 4),
        // property 'progress'
        QtMocHelpers::PropertyData<qreal>(35, QMetaType::QReal, QMC::DefaultPropertyFlags, 5),
    };
    QtMocHelpers::UintData qt_enums {
    };
    return QtMocHelpers::metaObjectData<MusicPlayer, qt_meta_tag_ZN11MusicPlayerE_t>(QMC::MetaObjectFlag{}, qt_stringData,
            qt_methods, qt_properties, qt_enums);
}
Q_CONSTINIT const QMetaObject MusicPlayer::staticMetaObject = { {
    QMetaObject::SuperData::link<QObject::staticMetaObject>(),
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN11MusicPlayerE_t>.stringdata,
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN11MusicPlayerE_t>.data,
    qt_static_metacall,
    nullptr,
    qt_staticMetaObjectRelocatingContent<qt_meta_tag_ZN11MusicPlayerE_t>.metaTypes,
    nullptr
} };

void MusicPlayer::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    auto *_t = static_cast<MusicPlayer *>(_o);
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: _t->tracksChanged(); break;
        case 1: _t->currentTrackChanged(); break;
        case 2: _t->playingChanged(); break;
        case 3: _t->durationChanged(); break;
        case 4: _t->positionChanged(); break;
        case 5: _t->progressChanged(); break;
        case 6: _t->playbackError((*reinterpret_cast< std::add_pointer_t<QString>>(_a[1]))); break;
        case 7: _t->handleStateChanged((*reinterpret_cast< std::add_pointer_t<QMediaPlayer::PlaybackState>>(_a[1]))); break;
        case 8: _t->handleErrorOccurred((*reinterpret_cast< std::add_pointer_t<QMediaPlayer::Error>>(_a[1])),(*reinterpret_cast< std::add_pointer_t<QString>>(_a[2]))); break;
        case 9: _t->handleDurationChanged((*reinterpret_cast< std::add_pointer_t<qint64>>(_a[1]))); break;
        case 10: _t->handlePositionChanged((*reinterpret_cast< std::add_pointer_t<qint64>>(_a[1]))); break;
        case 11: _t->handleMediaStatusChanged((*reinterpret_cast< std::add_pointer_t<QMediaPlayer::MediaStatus>>(_a[1]))); break;
        case 12: _t->loadLibrary((*reinterpret_cast< std::add_pointer_t<QString>>(_a[1]))); break;
        case 13: _t->loadLibrary(); break;
        case 14: _t->play((*reinterpret_cast< std::add_pointer_t<QString>>(_a[1]))); break;
        case 15: _t->play(); break;
        case 16: _t->pause(); break;
        case 17: _t->toggle((*reinterpret_cast< std::add_pointer_t<QString>>(_a[1]))); break;
        case 18: _t->next(); break;
        case 19: _t->previous(); break;
        default: ;
        }
    }
    if (_c == QMetaObject::IndexOfMethod) {
        if (QtMocHelpers::indexOfMethod<void (MusicPlayer::*)()>(_a, &MusicPlayer::tracksChanged, 0))
            return;
        if (QtMocHelpers::indexOfMethod<void (MusicPlayer::*)()>(_a, &MusicPlayer::currentTrackChanged, 1))
            return;
        if (QtMocHelpers::indexOfMethod<void (MusicPlayer::*)()>(_a, &MusicPlayer::playingChanged, 2))
            return;
        if (QtMocHelpers::indexOfMethod<void (MusicPlayer::*)()>(_a, &MusicPlayer::durationChanged, 3))
            return;
        if (QtMocHelpers::indexOfMethod<void (MusicPlayer::*)()>(_a, &MusicPlayer::positionChanged, 4))
            return;
        if (QtMocHelpers::indexOfMethod<void (MusicPlayer::*)()>(_a, &MusicPlayer::progressChanged, 5))
            return;
        if (QtMocHelpers::indexOfMethod<void (MusicPlayer::*)(const QString & )>(_a, &MusicPlayer::playbackError, 6))
            return;
    }
    if (_c == QMetaObject::ReadProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 0: *reinterpret_cast<QStringList*>(_v) = _t->tracks(); break;
        case 1: *reinterpret_cast<QString*>(_v) = _t->currentTrack(); break;
        case 2: *reinterpret_cast<bool*>(_v) = _t->isPlaying(); break;
        case 3: *reinterpret_cast<qint64*>(_v) = _t->duration(); break;
        case 4: *reinterpret_cast<qint64*>(_v) = _t->position(); break;
        case 5: *reinterpret_cast<qreal*>(_v) = _t->progress(); break;
        default: break;
        }
    }
}

const QMetaObject *MusicPlayer::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *MusicPlayer::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_staticMetaObjectStaticContent<qt_meta_tag_ZN11MusicPlayerE_t>.strings))
        return static_cast<void*>(this);
    return QObject::qt_metacast(_clname);
}

int MusicPlayer::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        if (_id < 20)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 20;
    }
    if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        if (_id < 20)
            *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType();
        _id -= 20;
    }
    if (_c == QMetaObject::ReadProperty || _c == QMetaObject::WriteProperty
            || _c == QMetaObject::ResetProperty || _c == QMetaObject::BindableProperty
            || _c == QMetaObject::RegisterPropertyMetaType) {
        qt_static_metacall(this, _c, _id, _a);
        _id -= 6;
    }
    return _id;
}

// SIGNAL 0
void MusicPlayer::tracksChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 0, nullptr);
}

// SIGNAL 1
void MusicPlayer::currentTrackChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 1, nullptr);
}

// SIGNAL 2
void MusicPlayer::playingChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 2, nullptr);
}

// SIGNAL 3
void MusicPlayer::durationChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 3, nullptr);
}

// SIGNAL 4
void MusicPlayer::positionChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 4, nullptr);
}

// SIGNAL 5
void MusicPlayer::progressChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 5, nullptr);
}

// SIGNAL 6
void MusicPlayer::playbackError(const QString & _t1)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 6, nullptr, _t1);
}
QT_WARNING_POP
