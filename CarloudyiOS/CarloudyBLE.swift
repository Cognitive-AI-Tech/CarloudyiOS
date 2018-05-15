//
//  CarloudyBLE.swift
//  CarloudyiOS
//
//  Created by Cognitive AI Technologies on 5/14/18.
//  Copyright © 2018 zijia. All rights reserved.
//

import Foundation
import CoreBluetooth
import CryptoSwift

extension String {
    subscript  (r: Range<Int>) -> String {
        get {
            let myNSString = self as NSString
            let start = r.lowerBound
            let length = r.upperBound - start + 1
            return myNSString.substring(with: NSRange(location: start, length: length))
        }
    }
}

open class CarloudyBLE: NSObject {
    
    open static let shareInstance : CarloudyBLE = CarloudyBLE()
    open let defaultKeySendToPairAndorid_ = "passwordpassword"
    open var newKeySendToPairAndorid_ = "passwordpassword"
    open var peripheralManager = CBPeripheralManager()
    open var dataToSend: NSData!
    open var datastring: String!
    //    var delegate: BLECentralDelegate?
    public override init() {
        super.init()
    }
    
    open func sendMessage(prefix : String, message : String){
        let str = prefix + message
        let data = stringToData(str: str)
        sendDataToPeripheral(data: data as NSData)
    }
    
    
    open func sendDataToPeripheral(data: NSData) {
        dataToSend = data
        startAdvertisingToPeripheral()
    }
    
    open func startAdvertisingToPeripheral() {
        if (dataToSend != nil){
            datastring = NSString(data:dataToSend as Data, encoding:String.Encoding.utf8.rawValue)! as String
            //            datastring = getAlphaNumericValue(str: datastring)
            let time1 = 130
            let time2 =  20
            let time = DispatchTime.now() + .milliseconds(time2)          //10
            let stop = DispatchTime.now() + .milliseconds(time1)      //140
            do {
                let aes = try AES(key: newKeySendToPairAndorid_, iv: "drowssapdrowssap", padding: .pkcs7)
                let ciphertext = try aes.encrypt(Array(datastring.utf8))
                DispatchQueue.main.asyncAfter(deadline: time) {
                    () -> Void in self.sendMessage(message: ciphertext );
                }
                DispatchQueue.main.asyncAfter(deadline: stop) {
                    () -> Void in self.peripheralManager.stopAdvertising();
                }
            } catch { }
            
        }
    }
    
    open func stringToData(str : String) -> Data{
        return str.data(using: String.Encoding.utf8)!
    }
    
    open func stopAdvertisingToPeripheral() {
        self.peripheralManager.stopAdvertising()
    }
    
    open func intToHex(value : Int) -> String{
        let st = String(format:"%02X", value)
        return st
    }
    
    open func sendMessage(message: Array<UInt8>){
        var UUID : String = ""
        var i = message.count - 1
        while i > -1 {
            let ints : Int = Int(message[i])
            UUID = UUID + intToHex(value: ints)
            i = i - 1
        }
        
        UUID = UUID[0..<31]
        let temp1 = UUID[0..<7] + "-" + UUID[8..<11] + "-"
        let temp2 = UUID[12..<15] + "-" + UUID[16..<19] + "-"
        let temp3 = UUID[20..<31]
        let messageUUID = temp1 + temp2 + temp3
        peripheralManager.stopAdvertising()
        peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [CBUUID(string: messageUUID)]])
    }
    
}

extension CarloudyBLE{
    
    open func pairButtonClicked(finish: @escaping ((String)->())){
        newKeySendToPairAndorid_ = "passwordpassword"
        let random6Num = String(arc4random_uniform(899999) + 100000)
        let stringToSend = "10key\(random6Num)"
        let dataToSend = stringToData(str: stringToSend)
        sendDataToPeripheral(data: dataToSend as NSData)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.newKeySendToPairAndorid_ = "\(random6Num)1111111111"
            finish(random6Num)
        }
    }
    
    open func toCarloudyApp() {
        let url = URL(string: "CarloudyiOS://")
        guard url != nil else {
            return
        }
        if UIApplication.shared.canOpenURL(url!){
            UIApplication.shared.open(url!)
        }else{
            print("user did not install Carloudy app")
        }
    }
}


