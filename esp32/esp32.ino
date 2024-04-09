#include "sd_read_write.h"
#include "SD_MMC.h"
#include "BLEDevice.h"
#include "BLEServer.h"
#include "BLEUtils.h"
#include "BLE2902.h"
#include "String.h"

#include "Arduino.h"
#include "FS.h"


String downloadCourse(fs::FS &fs, const char * dirname) {
  File root = fs.open(dirname);
    if(!root){
        Serial.println("Failed to open directory");
        return "";
    }
    if(!root.isDirectory()){
        Serial.println("Not a directory");
        return "";
    }

    File file = root.openNextFile();
    String filedetails = "SYNC";
    while(file){
        if(file.isDirectory()){
        } else {
            String filename = file.name();
            filedetails += "@@@" + filename + "\n\n";
            String filepath = "/data/" +  filename;
            File file1 = fs.open(filepath.c_str());
            if(!file1){
            }else {
              while(file1.available()){
                char ch = file1.read();
                filedetails+= ch;
              }
            }
            filedetails += '\n';
            file1.close();
            
        }
        file = root.openNextFile();
    }
    return filedetails;
}


String listCourse(fs::FS &fs, const char * dirname){

    File root = fs.open(dirname);
    if(!root){
        Serial.println("Failed to open directory");
        return "";
    }
    if(!root.isDirectory()){
        Serial.println("Not a directory");
        return "";
    }

    File file = root.openNextFile();
    String courses = "";
    while(file){
        if(file.isDirectory()){
            //Serial.print("  DIR : ");
            //Serial.println(file.name());
        } else {
            // Serial.print("  FILE: ");
            // Serial.print(file.name());
            // Serial.print("  SIZE: ");
            // Serial.println(file.size());
            String filename = file.name();
            courses += filename + "\n";
        }
        file = root.openNextFile();
    }
    return courses;
}

String readCourseFile(fs::FS &fs, const char * path){
    Serial.printf("Reading file: %s\n", path);

    File file = fs.open(path);
    String filedetails = "**READ**\n";
    if(!file){
        Serial.println("Failed to open file for reading");
        return filedetails;
    }
    
    while(file.available()){
      char ch = file.read();
      filedetails+= ch;
    }
    file.close();
    return filedetails;
}

#define SD_MMC_CMD 15 //Please do not modify it.
#define SD_MMC_CLK 14 //Please do not modify it. 
#define SD_MMC_D0  2  //Please do not modify it.



// BLE Configuration Start

BLECharacteristic *pCharacteristic;
bool deviceConnected = false;
uint8_t txValue = 0;
long lastMsg = 0;
String rxload="";
String lastLoad = "";
 
#define SERVICE_UUID           "6E400001-B5A3-F393-E0A9-E50E24DCCA9E" 
#define CHARACTERISTIC_UUID_RX "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
#define CHARACTERISTIC_UUID_TX "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"


class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
    };
    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
    }
};
 
class MyCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
      String rxValue = (pCharacteristic->getValue()).c_str();
      if (rxValue.length() > 0 && rxload != rxValue) {
        rxload="";
        for (int i = 0; i < rxValue.length(); i++){
          rxload +=(char)rxValue[i];
        }
      }
    }
};


void setupBLE(String BLEName){
  const char *ble_name=BLEName.c_str();
  BLEDevice::init(ble_name);
  BLEServer *pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());
  BLEService *pService = pServer->createService(SERVICE_UUID); 
  pCharacteristic= pService->createCharacteristic(CHARACTERISTIC_UUID_TX,BLECharacteristic::PROPERTY_NOTIFY);
  pCharacteristic->addDescriptor(new BLE2902());
  BLECharacteristic *pCharacteristic = pService->createCharacteristic(CHARACTERISTIC_UUID_RX,BLECharacteristic::PROPERTY_WRITE);
  pCharacteristic->setCallbacks(new MyCallbacks()); 
  pService->start();
  pServer->getAdvertising()->start();
  Serial.println("Waiting a client connection to notify...");
}

// BLE Configuration End


String removeWhitespace(String str) {
  String result = "";
  for (int i = 0; i < str.length(); i++) {
    char c = str.charAt(i);
    if (!isWhitespace(c)) {
      result += c;
    }
  }
  return result;
}

bool isWhitespace(char c) {
  return c == ' ' || c == '\t' || c == '\n' || c == '\r';
}

void setup(){
    Serial.begin(9600);
    Serial.setTimeout(100);
    setupBLE("ESP32_Bluetooth");
    SD_MMC.setPins(SD_MMC_CLK, SD_MMC_CMD, SD_MMC_D0);
    if (!SD_MMC.begin("/sdcard", true, true, SDMMC_FREQ_DEFAULT, 5)) {
      Serial.println("Card Mount Failed");
      return;
    }
    uint8_t cardType = SD_MMC.cardType();
    if(cardType == CARD_NONE){
        Serial.println("No SD_MMC card attached");
        return;
    }
}

void loop(){
    Serial.println("RXLOAD: " + rxload);
    if (lastLoad == rxload) {
      delay(2000);
      return;
    }
    lastLoad = rxload;
    if (deviceConnected&&rxload.length()>0) {
      if (rxload.substring(5) == "list_course") {
        String courses = listCourse(SD_MMC, "/data");
        const char *newValue=courses.c_str();
       
        pCharacteristic->setValue(newValue);
        pCharacteristic->notify();
        rxload == "";
      }
      else if (rxload.substring(5, 5+4) == "sync") {
        String data = downloadCourse(SD_MMC, "/data");
        const char *newValue= data.c_str();
        pCharacteristic->setValue(newValue);
        pCharacteristic->notify();
        delay(1000);
      }
      else if (rxload.substring(5, 5+4) == "read") {
        String filename = rxload.substring(5+5);
        rxload == "";
        Serial.println("Reading: " + filename);
        filename = "/data/" + filename;
        String details = readCourseFile(SD_MMC, filename.c_str());
        const char *newValue=details.c_str();
        pCharacteristic->setValue(newValue);
        pCharacteristic->notify();
        delay(1000);
      }
      else if (rxload.substring(5, 5+3) == "del") {
        String filename = rxload.substring(4+5);
        rxload == "";
        Serial.println("Deleting: " + filename);
        filename = "/data/" + filename;
        deleteFile(SD_MMC, filename.c_str());
        Serial.println("Deleted: " + filename);
        //send the new courses list
        String courses = listCourse(SD_MMC, "/data");
        const char *newValue=courses.c_str();
        pCharacteristic->setValue(newValue);
        pCharacteristic->notify();
        delay(1000);
      }
      else if (rxload.substring(5, 5+5) == "write") {
        Serial.println(rxload.substring(6+5));
        String filename = rxload.substring(6+5);
        rxload="";
        filename.trim();
        Serial.println(filename);
        writeFile(SD_MMC, filename.c_str(), "Date, Roll");
        
        delay(1000);
        listDir(SD_MMC, "/data", 0);
         //send the new courses list
        String courses = listCourse(SD_MMC, "/data");
        const char *newValue=courses.c_str();
        pCharacteristic->setValue(newValue);
        pCharacteristic->notify();
        delay(1000);
      }else {
        Serial.println(rxload);
      }
    }
    if(Serial.available()>0){
      String str=Serial.readString();
      str.trim();
      Serial.println("Expected: " + str);
      const char *newValue=str.c_str();
      pCharacteristic->setValue(newValue);
      pCharacteristic->notify();
    }
    rxload == "";
    delay(2000);
}