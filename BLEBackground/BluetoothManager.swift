//
//  BluetoothManager.swift
//  BLEBackground
//
//  Created by camacholaverde on 4/13/16.
//  Copyright © 2016 gibicgroup. All rights reserved.
//

import UIKit
import CoreBluetooth


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
    
    ///
    var centralManager:CBCentralManager!
    
    /// The connected bluetooth peripheral
    var connectedPeripheral:CBPeripheral?
    
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
        // PatientMonitor service 1
        // BLEBee service (v1.0.0) string UUID:
        let serviceUUIDString = "EF080D8C-C3BE-41FF-BD3F-05A5F4795D7F"
        
        // Read characteristic string UUID for the BLEBee Service
        let rxBLEBeeSeviceCharacteristicUUIDString = "A1E8F5B1-696B-4E4C-87C6-69DFE0B0093B"
        
        // Write characteristic string UUID for the BLEBee service
        let txBLEBeeServiceCharacteristicUUIDString = "1494440E-9A58-4CC0-81E4-DDEA7F74F623"
        
        // Initialize the characteristics dictionary for the BLEBee service
        let characteristics:[String:CBUUID] = ["WriteToBLEBee": CBUUID(string:rxBLEBeeSeviceCharacteristicUUIDString), "ReadFromBLEBee": CBUUID(string:txBLEBeeServiceCharacteristicUUIDString)]
        
        let bleBeeService = ServiceDescriptor(name: "BLEBleeService", UUIDString: serviceUUIDString, characteristics: characteristics)
        return [bleBeeService]
    }
    
    func serviceDescriptorForService(service:CBService)->ServiceDescriptor?{
        let descriptors  = self.servicesDescriptors.filter({$0.UUIDString == service.UUID.UUIDString});
        if descriptors.count>0{
            return descriptors.last!
        }
        return nil
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
        print("Found peripheral \(peripheral.name!). Will attempt to connect. \n The peripheral UUID \(peripheral.identifier)")
        //TODO:Verify if a more rigurous selection of the device is requiered. What if several devices have the same services?
        // It is important to have a reference to the peripheral that will be connected. Otherwise, the connection does not succeed (seems to be a bug?)
        self.connectedPeripheral = peripheral
        centralManager.connectPeripheral(peripheral, options: nil);
        
    }
    
    func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        print("did connnect to peripheral named \(peripheral.name!)")
        
        self.connectedPeripheral?.delegate = self
        //Start looking for the services of interest
        print("Will start searching for services")
        self.connectedPeripheral?.discoverServices(self.servicesDescriptors.map({$0.UUID()}))
    }
    
    func centralManager(central: CBCentralManager, didFailToConnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        if error != nil{
            print("The connection to peripheral", peripheral.name, "failed with error:", error?.description, separator: " ", terminator: "\n")
        }
        // Attempt a new connection to the device?
        if self.connectedPeripheral == peripheral{
            self.centralManager.connectPeripheral(peripheral, options: nil);
        }
        
    }
}


//MARK: - Bluetooth Peripheral Delegate
extension BluetoothManager:CBPeripheralDelegate{
    
    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        print("Services discovered")
        //For the given service, look up for the characteristics of interest
        for service in (connectedPeripheral?.services)!{
            let serviceDescriptor = servicesDescriptors.filter({$0.UUID().UUIDString == service.UUID.UUIDString}).first
            connectedPeripheral?.discoverCharacteristics(serviceDescriptor?.characteristicsUUID(), forService: service);
            print("Scanning characteristics for service \(serviceDescriptor?.name)");
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
            let serviceDescriptor = self.serviceDescriptorForService(service)
            let characteristicName = serviceDescriptor?.characteristicNameForCharacteristicUUID(characteristic.UUID)
            print("Found Characteristic", characteristicName , "of Service", serviceDescriptor?.name, separator: " ", terminator: "\n")
            
            // If the characteristic is readable, get notify when it chages
            if (characteristic.properties.rawValue & CBCharacteristicProperties.Read.rawValue) != 0 {
                connectedPeripheral?.setNotifyValue(true, forCharacteristic: characteristic)
                print("Will get notifications in changes of characteristic", characteristicName, "of service", serviceDescriptor?.name, separator: " ", terminator: "\n")
            }
        }
    }
}








