import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

FlutterBlue flutterBlue = FlutterBlue.instance;
String targetDeviceName = "ESP32_Bluetooth";
String characteristicUuid = "6e400003-b5a3-f393-e0a9-e50e24dcca9e";
bool isModalOpen = false;
String log = "";

String asciiValuesToString(List<int> asciiValues) {
  return String.fromCharCodes(asciiValues);
}

Future<void> connectToDeviceForRead(
    Rx<String> debugData, Rx<String> courses) async {
  List<BluetoothDevice> connectedDevices = await flutterBlue.connectedDevices;
  for (BluetoothDevice device in connectedDevices) {
    if (device.name == targetDeviceName) {
      debugData.value = "Device is already connected";
      discoverServices(device, debugData, courses);
      return;
    }
  }

  debugData.value = 'Scanning';
  // Start scanning
  flutterBlue.startScan(timeout: Duration(seconds: 4));

  // Listen to scan results
  var subscription = flutterBlue.scanResults.listen((results) async {
    for (ScanResult result in results) {
      if (result.device.name == targetDeviceName) {
        flutterBlue.stopScan();
        try {
          await result.device.connect();
          debugData.value = ("Connected to $targetDeviceName");
          discoverServices(result.device, debugData, courses);
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

void discoverServices(
    BluetoothDevice device, Rx<String> debugData, Rx<String> courses) async {
  List<BluetoothService> services = await device.discoverServices();
  for (BluetoothService service in services) {
    for (BluetoothCharacteristic characteristic in service.characteristics) {
      // Assuming you want to read from the characteristic

      if (characteristic.uuid.toString().toLowerCase() ==
          characteristicUuid.toLowerCase()) {
        // If you want to subscribe to notifications/indications
        characteristic.setNotifyValue(true);
        characteristic.value.listen((value) async {
          var valueStrs = asciiValuesToString(value);
          print(valueStrs);

          if (valueStrs.contains("SYNC") && !isModalOpen) {
            String showingValue = valueStrs.substring(4);
            showTextFile(showingValue.replaceAll('@@@', '\n'));
          }
          if (valueStrs.contains("READ") && !isModalOpen && log != valueStrs) {
            showTextFile(valueStrs.substring(9));
          } else if (!valueStrs.contains("SYNC") &&
              valueStrs.contains('txt') &&
              valueStrs != courses.value) {
            courses.value = valueStrs;
          } else if (!valueStrs.contains('txt')) {
            String elip = valueStrs.length > 150 ? "..." : "";
            debugData.value = ("Received data from ESP32:\n") +
                valueStrs.substring(0, min(valueStrs.length, 150)) +
                elip;
          }
          log = valueStrs;
        });
      }
    }
  }
}

Future<dynamic> showTextFile(String text) {
  isModalOpen = true;
  return showDialog(
    barrierDismissible: false,
    context: Get.context!,
    builder: (BuildContext context) {
      return AlertDialog(
        content: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text("Text File"),
              const SizedBox(height: 10),
              Text(text),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              isModalOpen = false;
            },
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              isModalOpen = false;
              saveToFile("Attendee.txt", text);
            },
            child: const Text('Download'),
          ),
        ],
      );
    },
  );
}

Future<void> saveToFile(String fileName, String content) async {
  Directory directory = await getApplicationDocumentsDirectory();
  String filePath = '${directory.path}/$fileName';

  // Write the file.
  File file = File(filePath);
  await file.writeAsString(content);

  // Show a dialog to confirm the file has been saved.
  showDialog(
    context: Get.context!,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('File Saved'),
        content: Text('File saved to $filePath'),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      );
    },
  );
}
