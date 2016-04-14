//
//  ViewController.swift
//  BLEBackground
//
//  Created by camacholaverde on 4/13/16.
//  Copyright © 2016 gibicgroup. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    var bluetoothManager:BluetoothManager!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Initialize the bluetooth manager.
        self.bluetoothManager = BluetoothManager()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

