//
//  BluetoothManager.swift
//  BLEBackground
//
//  Created by camacholaverde on 4/13/16.
//  Copyright © 2016 gibicgroup. All rights reserved.
//

import UIKit
import CoreBluetooth


enum CharacteristicsNames:String {
    case ReadFromBLEBeeKey = "ReadFromBLEBee"
    case SendToBLEBeeKey = "SendToBLEBee"
}


//MARK: - ServiceDescriptor

struct ServiceDescriptor {
    //MARK: Properties
    
    ///
    let name:String
    
    ///
    let UUIDString:String
    
    ///
    let characteristics:[String:CBUUID]
    
    //MARK: Methods
    
    /**
    */
    func UUID()->CBUUID{
        return CBUUID(string: self.UUIDString);
    }
    
    /**
    */
    func characteristicsUUID() -> [CBUUID]{
        return [CBUUID](characteristics.values);
    }
    
    /**
     Returns the characteristic name, given the characteristic UUID
    */
    func characteristicNameForCharacteristicUUID(UUID:CBUUID)->String?{
        for (key, value) in characteristics{
            if value == UUID{
                return key
            }
        }
        return nil
    }
}

//MARK: - BluetoothManager

class BluetoothManager: NSObject{
    
    //MARK: Properties
    
    /// Device UUID. Given that we might have several devices with the same services, a match between the iOS device and the BLE device must be performed. This configuration must be done as a setup of the application, and store the UUID of the device in the NSUserDefaults.
    let monitorDeviceUUIDString:String = "71719149-939D-55ED-E509-5AD1BC74C01E" //TODO: selection of device from user input. Store in NSUserDefaults.
    
    /// BLEBee service (v1.0.0) string UUID:
    static let monitorserviceUUIDString:String = "EF080D8C-C3BE-41FF-BD3F-05A5F4795D7F"
    
    static let monitorServiceName:String = "BLEBleeService"
    
    /// Read characteristic string UUID for the BLEBee Service
    static let rxBLEBeeSeviceCharacteristicUUIDString:String = "A1E8F5B1-696B-4E4C-87C6-69DFE0B0093B"
    
    /// Write characteristic string UUID for the BLEBee service
    static let txBLEBeeServiceCharacteristicUUIDString:String = "1494440E-9A58-4CC0-81E4-DDEA7F74F623"
    
    /// The CBCentral manager to handle the bluetooth devices and connections.
    var centralManager:CBCentralManager!
    
    /// The connected bluetooth peripheral
    var monitorPeripheral:CBPeripheral?
    
    /// Stores the writable characteristic of the Monitor peripheral device.
    var monitorWritableCharacteristic:CBCharacteristic?
    
    /// Hold an array of `ServiceDescriptor`s  in order to identify the services that will be serched
    let servicesDescriptors:[ServiceDescriptor] = BluetoothManager.loadServicesDescriptors();
    
    
    //MARK: Methods
    
    override init() {
        super.init()
        // Initialize the central manager.
        self.centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    /**
     Loads the descriptors for the sought services.
    */
    static func loadServicesDescriptors()->[ServiceDescriptor]{
        
        // Initialize the characteristics dictionary for the BLEBee service
        let characteristics:[String:CBUUID] = [CharacteristicsNames.ReadFromBLEBeeKey.rawValue: CBUUID(string:self.rxBLEBeeSeviceCharacteristicUUIDString), CharacteristicsNames.SendToBLEBeeKey.rawValue: CBUUID(string:txBLEBeeServiceCharacteristicUUIDString)]
        
        let bleBeeService = ServiceDescriptor(name: "BLEBleeService", UUIDString: monitorserviceUUIDString, characteristics: characteristics)
        return [bleBeeService]
    }
    
    /**
     Given a service, return the corresponding service descriptor.
    */
    func serviceDescriptorForService(service:CBService)->ServiceDescriptor?{
        let descriptors  = self.servicesDescriptors.filter({$0.UUIDString == service.UUID.UUIDString});
        if descriptors.count>0{
            return descriptors.last!
        }
        return nil
    }
    
    /**
     Reads the data received from peripheral. If a more sophisticated method is requiered, such as one including buffers of data, take a look at RedCodeMobile project.
    */
    func readDataFromPeripheral(data:NSData){
        var buffer:Int8 = 0x0
        data.getBytes(&buffer, length: data.length)

        
        /**
        //To read received data as integer
         var buffer:UInt8 = 0x0
         data.getBytes(&buffer, length: buffer.count)
        var bpm:UInt16?
        if (buffer.count >= 2){
            if (buffer[0] & 0x01 == 0){
                bpm = UInt16(buffer[1]);
            }else {
                bpm = UInt16(buffer[1]) << 8
                bpm =  bpm! | UInt16(buffer[2])
            }
        }
        
        if let actualBpm = bpm{
            print(actualBpm)
        }else {
            print(bpm)
        }
        */
        
        let newStr = NSString(UTF8String:&buffer)
        print(newStr)
    }
}

//MARK: - Bluetooth Manager Delegate Protocol conformance
extension BluetoothManager:CBCentralManagerDelegate{
    
    func centralManagerDidUpdateState(central: CBCentralManager) {
        print("Central manager did update state")
        
        switch central.state{
        case .PoweredOn:
            print("poweredOn")
            
            // As soon as the device is on, try stablish connection with previously connected devices, if any, or scan for
            
            let servicesUUIDs:[CBUUID] = self.servicesDescriptors.map({$0.UUID()})
            print("services of interest:\(servicesUUIDs)")
            let connectedPeripherals = centralManager.retrieveConnectedPeripheralsWithServices(servicesUUIDs)
            
            if connectedPeripherals.count > 0{
                for peripheralDevice in connectedPeripherals{
                    self.centralManager.connectPeripheral(peripheralDevice, options: nil);
                }
            }
            else {
                print("Scanning for periopherals")
                centralManager.scanForPeripheralsWithServices(servicesUUIDs, options: [CBCentralManagerScanOptionAllowDuplicatesKey:true])
            }
            
        default:
            print(central.state)
        }
    }
    
    func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        // Attempt to connect to the discovered device.
        centralManager.stopScan()
        print("Found peripheral \(peripheral.name!)")
        //TODO:Verify if a more rigurous selection of the device is requiered. What if several devices have the same services?
        // It is important to have a reference to the peripheral that will be connected. Otherwise, the connection does not succeed (seems to be a bug?)
        if peripheral.identifier.UUIDString == self.monitorDeviceUUIDString{
            print("Will attempt to connect. The peripheral UUID \(peripheral.identifier)")
            self.monitorPeripheral = peripheral
            centralManager.connectPeripheral(peripheral, options: [CBConnectPeripheralOptionNotifyOnNotificationKey: NSNumber(bool:true)])
        }
    }
    
    func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        
        print("did connnect to peripheral named \(peripheral.name!)")
        
        // Set ourselfs as the delegate for the connected peripheral.
        self.monitorPeripheral?.delegate = self
        
        //Start looking for the services of interest
        print("Will start searching for services")
        self.monitorPeripheral?.discoverServices(self.servicesDescriptors.map({$0.UUID()}))
    }
    
    func centralManager(central: CBCentralManager, didFailToConnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        if error != nil{
            print("The connection to peripheral", peripheral.name, "failed with error:", error?.description, separator: " ", terminator: "\n")
        }
        // Attempt a new connection to the device?
        if self.monitorPeripheral == peripheral{
            self.centralManager.connectPeripheral(peripheral, options: nil);
        }
        
    }
}


//MARK: - Bluetooth Peripheral Delegate
extension BluetoothManager:CBPeripheralDelegate{
    
    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        if error != nil{
            print("An error occured discovering services for peripheral")
        }
        else{
            print("Services discovered")
            //For the given service, look up for the characteristics of interest
            for service in (monitorPeripheral?.services)!{
                let serviceDescriptor = servicesDescriptors.filter({$0.UUID().UUIDString == service.UUID.UUIDString}).first
                monitorPeripheral?.discoverCharacteristics(serviceDescriptor?.characteristicsUUID(), forService: service);
                print("Scanning characteristics for service \(serviceDescriptor?.name)");
            }
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        
        if error != nil{
            print("an error ocurred during characteristics discovering process for the service",
                  servicesDescriptors.filter({$0.UUID().UUIDString == service.UUID.UUIDString}).first,
                  "The error description:",
                  error?.description, separator: " ", terminator: "\n")
            return
        }
        
        // Get notified of changes in the service characteristics
        for characteristic in service.characteristics!{
            // Print the and service for this characteristic
            if let serviceDescriptor = self.serviceDescriptorForService(service), let characteristicName = serviceDescriptor.characteristicNameForCharacteristicUUID(characteristic.UUID) {
                print("Found Characteristic", characteristicName , "of Service", serviceDescriptor.name, separator: " ", terminator: "\n")
                if serviceDescriptor.name == BluetoothManager.monitorServiceName{
                    switch characteristic.UUID.UUIDString {
                    case (serviceDescriptor.characteristics[CharacteristicsNames.ReadFromBLEBeeKey.rawValue]?.UUIDString)!:
                        print("Found ReadFromBLEBee characteristic")
                        // If the characteristic is readable, get notify when it chages
                        if (characteristic.properties.rawValue & CBCharacteristicProperties.Read.rawValue) != 0 {
                            monitorPeripheral?.setNotifyValue(true, forCharacteristic: characteristic)
                            print("Will get notifications in changes of characteristic", characteristicName, "with uuid", characteristic.UUID,"of service", serviceDescriptor.name, separator: " ", terminator: "\n")
                        }
                    case (serviceDescriptor.characteristics[CharacteristicsNames.SendToBLEBeeKey.rawValue]?.UUIDString)!:
                        print("Found writable characteristic")
                        self.monitorWritableCharacteristic = characteristic
                        
                    default:
                        break
                    }
                }
            }
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        let service = characteristic.service
        if let serviceDescriptor = self.serviceDescriptorForService(service), let characteristicName = serviceDescriptor.characteristicNameForCharacteristicUUID(characteristic.UUID){
            print("Did receive update notification for characterisitic with name: \(characteristicName)")
            if characteristicName == CharacteristicsNames.ReadFromBLEBeeKey.rawValue{
                print("Now read the value from the Monitor readable characteristic")
                readDataFromPeripheral(characteristic.value!)                
            }
        }
    }
}
