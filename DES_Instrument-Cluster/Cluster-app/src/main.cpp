#include "InstrumentCluster.h"

#include <QDebug>

int main(int argc, char *argv[]) {
	int appExit = EXIT_FAILURE;
	
	try {
		QGuiApplication app(argc, argv);

		InstrumentCluster cluster;
		ViewModel model;

		const std::shared_ptr<SharedMemory>& vehicle = cluster.getVehicle();
		const std::shared_ptr<GearManager>& gearManager = cluster.getGearManager();

		if (vehicle && vehicle->isValid()) {
			model.setVehicle(vehicle);

			cluster.setTimer("drivemode");
			cluster.connectTimerModel("drivemode", 300, model, &ViewModel::receiveTimeout);

			if (gearManager) {
				gearManager->setVehicleMemory(vehicle);
			}
		}
		
		const std::shared_ptr<BatteryMonitor>& battery = cluster.getBattery();
		if (battery && battery->isConnected()) {
			model.setBattery(battery);

			cluster.setTimer("battery");
			cluster.connectTimerModel("battery", 5000, model, &ViewModel::receiveTimeout);
		}

		if (cluster.openCan("can1")) {
			cluster.connectCanModel("can1", model, &ViewModel::receiveCanData);
		}

		if (gearManager) {
			GearManager* gearManagerPtr = gearManager.get();
			QObject::connect(&model, &ViewModel::updateDriveMode, gearManagerPtr,
				[gearManagerPtr, &model]() {
					if (gearManagerPtr) {
						gearManagerPtr->updateFromCluster(model.driveMode(), QStringLiteral("InstrumentCluster"));
					}
				});

			QObject::connect(gearManagerPtr, &GearManager::GearChanged, &model,
				[&model](quint8 gear, const QString&, quint32) {
					model.applyGearUpdate(gear);
				});

			gearManagerPtr->updateFromCluster(model.driveMode(), QStringLiteral("InstrumentCluster"));
		}
		
		cluster.registerModel("ViewModel", model);
		cluster.loadQml("qrc:/Main.qml", app);
		appExit = app.exec();

	} catch (const std::exception& e) {
		qCritical() << "Application error:" << e.what();
	}

	return appExit;
}
