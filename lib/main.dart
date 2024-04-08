import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bluesensor/read_data.dart';
import 'package:bluesensor/send_data.dart';

Rx<String> debugData = ''.obs;
String dataToSend = "";
Rx<bool> isDeviceConnected = false.obs;
Rx<String> courses = ''.obs;

String selectedOption = '';
void main() {
  Timer.periodic(const Duration(seconds: 2), (timer) async {
    isDeviceConnected.value = await checkConnectionForSend();
  });
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
        title: 'Blue Sensor',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: false,
        ),
        home: const Splash());
  }
}

class Splash extends StatefulWidget {
  const Splash({super.key});

  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> {
  @override
  void initState() {
    super.initState();
    Timer(
        const Duration(seconds: 3),
        () => Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (context) => const Home())));
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("Attendee", style: TextStyle(fontSize: 24)),
          SizedBox(
            height: 30,
          ),
          CircularProgressIndicator()
        ],
      )),
    );
  }
}

class Home extends StatelessWidget {
  const Home({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    () async {
      await connectToDeviceForRead(debugData, courses);
    }();
    return Scaffold(
      body: Center(
          child: Padding(
        padding: const EdgeInsets.all(20.0), // Decreased padding
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  Obx(() {
                    String status =
                        isDeviceConnected.value ? "Connected" : "Not Connected";
                    return Text("BT STATUS\n$status",
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600, // Decreased font size
                            color: isDeviceConnected.value
                                ? Colors.green
                                : Colors.red));
                  }),
                  const Spacer(),
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                      ),
                      onPressed: () {
                        connectToDeviceForRead(debugData, courses);
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(Icons.bluetooth_connected),
                          SizedBox(width: 8),
                          Text('Reconnect')
                        ],
                      )),
                ],
              ),
              const SizedBox(height: 20),
              const Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Add a new course",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: MediaQuery.of(context).size.width - 70 - 40,
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Course Name',
                      ),
                      onChanged: (value) {
                        dataToSend = value;
                      },
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 70,
                    child: ElevatedButton(
                        onPressed: () async {
                          if (dataToSend.isNotEmpty) {
                            if (await writeData(
                                "write /data/${dataToSend.replaceAll(' ', '_')}.txt",
                                debugData)) {
                              Get.snackbar("Success",
                                  "Course has been added successfully! It may take some time to appear in the list",
                                  snackPosition: SnackPosition.BOTTOM,
                                  backgroundColor: Colors.green,
                                  colorText: Colors.white,
                                  duration: const Duration(seconds: 2));
                            } else {
                              Get.snackbar("Error",
                                  "Please Check Your Connection. Please tap the reset button on the ESP32 device",
                                  snackPosition: SnackPosition.BOTTOM,
                                  backgroundColor: Colors.red,
                                  colorText: Colors.white,
                                  duration: const Duration(seconds: 2));
                            }
                          }
                        },
                        child: const Text('Add')),
                  ),
                  const Spacer(),
                ],
              ),
              const SizedBox(
                height: 30,
              ),
              Row(
                children: [
                  const Text(
                    "List of courses",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  GestureDetector(
                      onTap: () => writeData("list_course", debugData),
                      child: const Icon(Icons.refresh_sharp)),
                ],
              ),
              const SizedBox(
                height: 20,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Obx(() {
                    final List<String> dropdownOptions =
                        courses.value.split("\n").toList();
                    if (dropdownOptions.isNotEmpty) {
                      dropdownOptions.removeLast();
                      if (!dropdownOptions.contains(selectedOption)) {
                        selectedOption = '';
                      }
                    } else {
                      return const Text("Nothing to Delete");
                    }
                    List<DropdownMenuItem<String>> dropdownItems = [];

                    for (String option in dropdownOptions) {
                      if (option.isNotEmpty) {
                        dropdownItems.add(DropdownMenuItem<String>(
                          value: option,
                          child: Text(option),
                        ));
                      }
                    }

                    if (dropdownOptions.isNotEmpty) {
                      return SizedBox(
                        width: MediaQuery.of(context).size.width - 40,
                        child: DropdownButtonHideUnderline(
                          child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              decoration: InputDecoration(
                                counterText: "",
                                contentPadding: const EdgeInsets.symmetric(
                                    vertical: 16.0, horizontal: 20.0),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                // Add more decoration..
                              ),
                              items: dropdownItems,
                              hint: Text(
                                'Select a Course',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context).hintColor,
                                ),
                              ),
                              value:
                                  selectedOption == '' ? null : selectedOption,
                              onChanged: (String? value) {
                                selectedOption = value!;
                                courses.refresh();
                              }),
                        ),
                      );
                    } else {
                      return const Text("Nothing to Delete");
                    }
                  }),
                ],
              ),
              const SizedBox(
                height: 20,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 75,
                    child: ElevatedButton(
                        onPressed: () {
                          if (selectedOption != '') {
                            writeData("read $selectedOption", debugData);
                          }
                        },
                        child: const Text('Read')),
                  ),
                  const SizedBox(
                    width: 10,
                  ),
                  ElevatedButton(
                      style: ButtonStyle(
                        backgroundColor: MaterialStateProperty.all(Colors.red),
                      ),
                      onPressed: () {
                        if (selectedOption != '') {
                          writeData("del $selectedOption", debugData);
                        }
                      },
                      child: const Text('Delete')),
                  const SizedBox(
                    width: 10,
                  ),
                  ElevatedButton(
                      style: ButtonStyle(
                        backgroundColor:
                            MaterialStateProperty.all(Colors.black),
                      ),
                      onPressed: () {
                        writeData("sync", debugData);
                      },
                      child: const Text('Sync Data')),
                ],
              ),
              const SizedBox(
                height: 10,
              ),
              const SizedBox(
                height: 10,
              ),
              Obx(() => Text(debugData.value)),
            ],
          ),
        ),
      )),
    );
  }
}
