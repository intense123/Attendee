import 'package:flutter_blue/flutter_blue.dart';
import 'package:get/get.dart';

FlutterBlue flutterBlue = FlutterBlue.instance;
String targetDeviceName = "ESP32_Bluetooth";
String characteristicUuid = "6e400003-b5a3-f393-e0a9-e50e24dcca9e";

String asciiValuesToString(List<int> asciiValues) {
  return String.fromCharCodes(asciiValues);
}

Future<void> connectToDeviceForRead(Rx<String> debugData) async {
  List<BluetoothDevice> connectedDevices = await flutterBlue.connectedDevices;
  for (BluetoothDevice device in connectedDevices) {
    if (device.name == targetDeviceName) {
      debugData.value = "Device is already connected";
      discoverServices(device, debugData);
      return;
    }
  }

  debugData.value = 'Scanning';
  // Start scanning
  flutterBlue.startScan(timeout: Duration(seconds: 4));

  // Listen to scan results
  var subscription = flutterBlue.scanResults.listen((results) async {
    for (ScanResult result in results) {
      print(result.device.name);
      if (result.device.name == targetDeviceName) {
        flutterBlue.stopScan();
        try {
          await result.device.connect();
          debugData.value = ("Connected to $targetDeviceName");
          discoverServices(result.device, debugData);
        } catch (e) {
          debugData.value = ("Failed to connect: $e");
        }
        break;
      } else {
        debugData.value = 'Cannot find the device';
      }
    }
  });

  // Stop scanning after a timeout
  await Future.delayed(const Duration(seconds: 4));
  flutterBlue.stopScan();
  subscription.cancel();
  debugData.value = ("Scan Finished");
}

void discoverServices(BluetoothDevice device, Rx<String> debugData) async {
  List<BluetoothService> services = await device.discoverServices();
  for (BluetoothService service in services) {
    print(service.uuid.toString());
    for (BluetoothCharacteristic characteristic in service.characteristics) {
      // Assuming you want to read from the characteristic
      print(characteristic.uuid.toString());

      if (characteristic.uuid.toString().toLowerCase() ==
          characteristicUuid.toLowerCase()) {
        var value = await characteristic.read();
        var valueStr = asciiValuesToString(value);
        debugData.value = ("Received data from ESP32: $valueStr");

        // If you want to subscribe to notifications/indications
        characteristic.setNotifyValue(true);
        characteristic.value.listen((value) {
          var valueStrs = asciiValuesToString(value);
          debugData.value = ("Received data from ESP32: $valueStrs");
        });
      }
    }
  }
}
