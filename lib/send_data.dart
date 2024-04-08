import 'dart:math';

import 'package:flutter_blue/flutter_blue.dart';
import 'dart:convert';

import 'package:get/get.dart'; // For encoding strings to bytes

FlutterBlue flutterBlue = FlutterBlue.instance;
String targetDeviceName = "ESP32_Bluetooth";
String characteristicUuid = "6e400002-b5a3-f393-e0a9-e50e24dcca9e";
String dataToSend = "Hello, Bluetooth!";

// Check if the target device is already connected

Future<bool> checkConnectionForSend() async {
  bool isTargetDeviceConnected = false;
  List<BluetoothDevice> connectedDevices = await flutterBlue.connectedDevices;
  for (BluetoothDevice device in connectedDevices) {
    if (device.name == targetDeviceName) {
      isTargetDeviceConnected = true;
      break;
    }
  }
  return isTargetDeviceConnected;
}

const _chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
Random _rnd = Random();

String getRandomString(int length) => String.fromCharCodes(Iterable.generate(
    length, (_) => _chars.codeUnitAt(_rnd.nextInt(_chars.length))));

Future<bool> writeData(String data, Rx<String> debugData) async {
  bool isDeviceConnected = await checkConnectionForSend();
  if (isDeviceConnected) {
    List<BluetoothDevice> connectedDevices = await flutterBlue.connectedDevices;
    for (BluetoothDevice device in connectedDevices) {
      if (device.name == targetDeviceName) {
        List<BluetoothService> services = await device.discoverServices();
        for (BluetoothService service in services) {
          for (BluetoothCharacteristic characteristic
              in service.characteristics) {
            if (characteristic.uuid.toString().toLowerCase() ==
                characteristicUuid.toString().toLowerCase()) {
              data = getRandomString(5) + data;
              List<int> bytes = utf8.encode(data);
              await characteristic.write(bytes);
              return true;
            }
          }
        }
        break;
      }
    }
  } else {
    debugData.value = ("Cannot send data because device is not connected.");
  }
  return false;
}
