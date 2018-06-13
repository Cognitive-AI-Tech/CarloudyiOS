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
import CoreLocation

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
    
    open static let shareInstance : CarloudyBLE = {
        let ble = CarloudyBLE()
        ble.getPairKey()
        return ble
    }()
    open let defaultKeySendToPairAndorid_ = "passwordpassword"
    open var newKeySendToPairAndorid_ = "passwordpassword"{
        didSet{
            savePairKey()
        }
    }
    open var peripheralManager = CBPeripheralManager()
    
    ///The array saved all datas
    var dataArray : Array<String> = []
    open var dataArrayTimerInterval = 0.15
    weak var dataArrayTimer : Timer?
    
    public override init() {
        super.init()
    }
    
    /// highPriority only works if message.count less or equal than maxLenthEachData = 11
    ///if u set coverTheFront ture, all the elements in dataArray with same prefix will be removed.
    open func sendMessageForSplit(prefix : String, message : String, highPriority : Bool = false, coverTheFront: Bool = false){
        if prefix.count > 2{
            print("prefix better has 2 characters")
        }
        if coverTheFront == true{
            for (index, data) in dataArray.enumerated(){
                if String(data[data.index(data.startIndex, offsetBy: 2)..<data.index(data.startIndex, offsetBy: 4)]) == prefix{
                    sync(lock: dataArray, closure: {
                        self.dataArray.remove(at: index)
                    })
                }
            }
        }
        
        let maxLenthEachData = 11
        let datasCount = Int(ceil(Double(message.count) / Double(maxLenthEachData)))
        let startingValue = Int(("0" as UnicodeScalar).value) // 48
        let total = Character(UnicodeScalar(datasCount + startingValue)!)
        
        for index in 0..<datasCount{
            
            let i2 = Character(UnicodeScalar(index + startingValue)!)
            var piece = ""
            if (message.count - (maxLenthEachData * index)) > maxLenthEachData{
                piece = "\(total)\(i2)\(prefix)\(message[(maxLenthEachData * index)..<(maxLenthEachData * (index + 1) - 1)])"
            }else{
                piece = "\(total)\(i2)\(prefix)\(message[(maxLenthEachData * index)..<(message.count-1)])"
            }
            
            if highPriority == true && piece.hasPrefix("10"){
                //                for (index, data) in dataArray.enumerated(){
                //                    if data.hasPrefix("10\(prefix)"){
                //                        dataArray.remove(at: index)
                //                    }
                //                }
                //                dataArray.insert(piece, at: 0)
                sync(lock: dataArray as Array<Any>, closure: {
                    dataArray.insert(piece, at: 0)
                })
            }else{
                sync(lock: dataArray as Array<Any>, closure: {
                    dataArray.append(piece)
                })
            }
            
        }
        openDataArrayTimer()
    }
    
    func openDataArrayTimer(){
        guard dataArrayTimer == nil else {
            return
        }
        dataArrayTimer =  Timer.scheduledTimer(withTimeInterval: dataArrayTimerInterval, repeats: true) { (_) in
            if self.dataArray.count > 0{
                let stringToSend = self.dataArray.first
                print("-------------dataArray.count: --\(self.dataArray.count)")
                self.sync(lock: self.dataArray, closure: {
                    self.dataArray.removeFirst()
                })
                self.sendMessage(message: stringToSend ?? "")
            }else{
                self.dataArrayTimer?.invalidate()
            }
        }
    }
    
    fileprivate func sendMessage(message : String){
        let data = stringToData(str: message)
        sendDataToPeripheral(data: data as NSData)
    }
    
    
    open func sendDataToPeripheral(data: NSData) {
        let dataToSend = data
        startAdvertisingToPeripheral(dataToSend: dataToSend)
    }
    
    open func startAdvertisingToPeripheral(dataToSend : NSData) {
        let datastring = NSString(data:dataToSend as Data, encoding:String.Encoding.utf8.rawValue)! as String
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

//MARK: -- pairkey
extension CarloudyBLE{
    
    open func openUrl(url: URL){
        let urlStr = String(describing: url)
        if let pairKey = urlStr.components(separatedBy: "://").last{
            newKeySendToPairAndorid_ = pairKey
            print("2----\(newKeySendToPairAndorid_)")
        }
    }
    
    open func savePairKey(){
        UserDefaults.standard.set(newKeySendToPairAndorid_, forKey: "newKeySendToPairAndorid_")
    }
    
    open func getPairKey(){
        if UserDefaults.standard.object(forKey: "newKeySendToPairAndorid_") != nil {
            newKeySendToPairAndorid_ = UserDefaults.standard.object(forKey: "newKeySendToPairAndorid_") as! String
        }
    }
}


///数组安全问题
extension CarloudyBLE{
    func sync(lock: Array<Any>, closure: () -> Void) {
        objc_sync_enter(lock)
        closure()
        objc_sync_exit(lock)
    }
    /*
     var list = NSMutableArray()
     sync (list) {
     list.addObject("something")
     }
     */
}

