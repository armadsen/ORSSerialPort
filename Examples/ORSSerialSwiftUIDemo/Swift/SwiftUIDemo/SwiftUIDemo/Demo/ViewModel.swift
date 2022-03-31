//
//  ViewModel.swift
//  SerialPort
//
//  Created by Jan Anstipp on 30.09.20.
//

import Foundation
import ORSSerial
import SwiftUI
import Combine

class ViewModel: ObservableObject{
    
    @Published var settings = PortSettings()
    @Published var settingsDebug = PortSettings()
    @Published var serialPort: ORSSerialPortCombine?
    @Published var availablePorts: [String] = []
    @Published var path: String = ""
    @Published var recieve: String = ""
    
    
    private var subSet = Set<AnyCancellable>()
    private var manager = ORSSerialPortManager.shared()
    
    init(){
        $path.sink{self.newPort($0)}.store(in: &subSet)
        manager.publisher(for: \.availablePorts).map{ $0.map{$0.path} }.assign(to: \.availablePorts, on: self).store(in: &subSet)
    }
    
    private func newPort(_ path: String){
        serialPort = ORSSerialPortCombine(path)
        serialPort?.portSettingsSub
            .assign(to: \.settings, on: self)
            .store(in: &subSet)
        
        serialPort?.receiveDataSub
            .sink{data in
                self.recieve += String(decoding: data, as: UTF8.self)
            }.store(in: &subSet)
    }
    
}

struct PortSettings{
    var path: String = ""
    var name: String = ""
    var isOpen: Bool = false
    var isConnect: Bool = false
    var cts: Bool = false
    var dsr: Bool = false
    var usesDCDOutputFlowControl: Bool = false
    var baudRate: Int = 9600
    var numberOfStopBits: Int = 1
    var usesRTSCTSFlowControl: Bool = false
    var usesDTRDSRFlowControl: Bool = false
    var rts: Bool = false
    var dtr: Bool = false
    var dcdIn: Bool = false
    var echo: Bool = false
    var parity: ORSSerialPortParity = .none
    var numberOfDataBits: Int = 0
    var allowsNonStandardBaudRates: Bool = false
    init(){}
}

extension PortSettings{
    
    init(_ port: ORSSerialPort,isConnect: Bool){
        baudRate = Int(truncating: port.baudRate)
        numberOfStopBits = Int(port.numberOfStopBits)
        parity = port.parity
        usesRTSCTSFlowControl = port.usesRTSCTSFlowControl
        usesDTRDSRFlowControl = port.usesDTRDSRFlowControl
        usesDCDOutputFlowControl = port.usesDCDOutputFlowControl
        echo = port.shouldEchoReceivedData
        rts = port.rts
        dtr = port.dtr
        numberOfDataBits = Int(port.numberOfDataBits)
        self.isConnect = isConnect
        isOpen = port.isOpen
        name = port.name
        path = port.path
        cts = port.cts
        dsr = port.dsr
        dcdIn = port.dcd
        allowsNonStandardBaudRates = port.allowsNonStandardBaudRates
    }
}

// For debugging

extension ViewModel {
    func updatePortTestSetting(){
        guard let port = serialPort?.port else { return }
        settingsDebug.path = port.path
        settingsDebug.name = port.name
        settingsDebug.cts = port.cts
        settingsDebug.dsr = port.dsr
        settingsDebug.usesDCDOutputFlowControl = port.usesDCDOutputFlowControl
        settingsDebug.baudRate = Int(truncating: port.baudRate)
        settingsDebug.numberOfStopBits = Int(port.numberOfStopBits)
        settingsDebug.usesRTSCTSFlowControl = port.usesRTSCTSFlowControl
        settingsDebug.usesDTRDSRFlowControl = port.usesDTRDSRFlowControl
        settingsDebug.rts = port.rts
        settingsDebug.dtr = port.dtr
        settingsDebug.dcdIn = port.dcd
        settingsDebug.echo = port.shouldEchoReceivedData
        settingsDebug.parity = port.parity
        settingsDebug.numberOfDataBits = Int(port.numberOfDataBits)
        settingsDebug.allowsNonStandardBaudRates = port.allowsNonStandardBaudRates
        settingsDebug.isOpen = port.isOpen
        
    }
    
}
