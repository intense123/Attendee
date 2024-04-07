import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:get/get.dart';
import 'package:bluesensor/read_data.dart';
import 'package:bluesensor/send_data.dart';

void main() {
  runApp(const MyApp());
}

Rx<String> debugData = ''.obs;
BluetoothDevice? myDevice;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Blue Sensor',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: Scaffold(
          body: Center(
              child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ElevatedButton(
                  onPressed: () {
                    writeData("Hello World", debugData);
                  },
                  child: const Text('Write Data')),
              ElevatedButton(
                  onPressed: () {
                    connectToDeviceForRead(debugData);
                  },
                  child: const Text('Refresh')),
              const SizedBox(
                height: 10,
              ),
              Obx(() => Text(debugData.value)),
            ],
          )),
        ));
  }
}
