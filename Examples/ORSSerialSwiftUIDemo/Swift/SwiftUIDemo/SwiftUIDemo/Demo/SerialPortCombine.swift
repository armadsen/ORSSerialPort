//
//  SerialPort.swift
//  SerialPort
//
//  Created by Jan Anstipp on 30.09.20.
//

import Foundation
import ORSSerial
import Combine


class ORSSerialPortCombine:NSObject, ObservableObject {
    
    @Published var baudRate: Int
    @Published var allowsNonStandardBaudRates: Bool
    @Published var numberOfStopBits: Int
    @Published var parity: ORSSerialPortParity
    @Published var usesRTSCTSFlowControl: Bool
    @Published var usesDTRDSRFlowControl: Bool
    @Published var usesDCDOutputFlowControl: Bool
    @Published var shouldEchoReceivedData: Bool
    @Published var rts: Bool
    @Published var dtr: Bool
    @Published var numberOfDataBits: Int
    
    var receiveDataSub: AnyPublisher<Data,Never> { receiveData.eraseToAnyPublisher() }
    var receivePacketSub: AnyPublisher<(data: Data,description:ORSSerialPacketDescriptor),Never> { receivePacket.eraseToAnyPublisher() }
    var errorSub: AnyPublisher<Error,Never> { error.eraseToAnyPublisher() }
    var responseDataSub: AnyPublisher<(data:Data,request:ORSSerialRequest),Never> { responseData.eraseToAnyPublisher() }
    var requestTimeoutSub: AnyPublisher<ORSSerialRequest,Never> { requestTimeout.eraseToAnyPublisher() }
    var portSettingsSub: AnyPublisher<PortSettings,Never> { portSettings.eraseToAnyPublisher() }

    private var isConnect: CurrentValueSubject<Bool,Never>
    private var isOpen: CurrentValueSubject<Bool,Never>
    private var receiveData = PassthroughSubject<Data,Never>()
    private var receivePacket = PassthroughSubject<(data:Data,description:ORSSerialPacketDescriptor),Never>()
    private var error = PassthroughSubject<Error,Never>()
    private var responseData = PassthroughSubject<(data:Data,request:ORSSerialRequest),Never>()
    private var requestTimeout = PassthroughSubject<ORSSerialRequest,Never>()
    private var portSettings: CurrentValueSubject<PortSettings,Never>
    
    // pendingRequest, queuedRequests we need CurrentValueSubject or PassthroughSubject?
    // var pendingRequest: CurrentValueSubject<ORSSerialRequest,Never>
    // var queuedRequests: CurrentValueSubject<ORSSerialRequest,Never>
    
    var name: String { port.name }
    var path: String { port.path }
    
    var packetDescriptors: [ORSSerialPacketDescriptor] { port.packetDescriptors }
    // cant use it in swift
    // var ioKitDevice: IOKitDevice { port.ioKitDevice }
    
    //is private only for debuggin public
    let port: ORSSerialPort
    private var subSet = Set<AnyCancellable>()
    
    func open(){ port.open() }
    func close(){ port.close() }
    
    func send(value:String, suffix: String){
        var data = value
        if !data.hasSuffix("\n") {
            data += suffix
        }
        if let data = data.data(using: .utf8) {
            port.send(data)
        }
    }
    
    init?(_ path: String){
        guard let newPort = ORSSerialPort(path: path) else {  return nil }
        port = newPort
        
        baudRate = Int(truncating: port.baudRate)
        numberOfStopBits = Int(port.numberOfStopBits)
        parity = port.parity
        usesRTSCTSFlowControl = port.usesRTSCTSFlowControl
        usesDTRDSRFlowControl = port.usesDTRDSRFlowControl
        usesDCDOutputFlowControl = port.usesDCDOutputFlowControl
        shouldEchoReceivedData = port.shouldEchoReceivedData
        rts = port.rts
        dtr = port.dtr
        numberOfDataBits = Int(port.numberOfDataBits)
        isConnect = .init(true)
        isOpen = .init(port.isOpen)
        allowsNonStandardBaudRates = port.allowsNonStandardBaudRates
        portSettings = .init(PortSettings(port, isConnect: false))
        
        super.init()
        port.delegate = self
        initPublisherSub()
        initKVOSub()
        initNotificationSub()
    }
    
    deinit {
        port.delegate = nil
    }
    
    func initPublisherSub(){
        $baudRate
            .removeDuplicates()
            .sink{value in
                self.port.baudRate = NSNumber(value: value)
                self.portSettings.send(PortSettings(self.port, isConnect: self.isConnect.value)) }
            .store(in: &subSet)
        $numberOfStopBits
            .removeDuplicates()
            .map{UInt($0)}
            .sink{value in
                self.port.numberOfStopBits = value
                self.portSettings.send(PortSettings(self.port, isConnect: self.isConnect.value)) }
            .store(in: &subSet)
        $parity
            .removeDuplicates()
            .sink{value in
                self.port.parity = value
                self.portSettings.send(PortSettings(self.port, isConnect: self.isConnect.value)) }
            .store(in: &subSet)
        $usesRTSCTSFlowControl
            .removeDuplicates()
            .sink{value in
                self.port.usesRTSCTSFlowControl = value
                self.portSettings.send(PortSettings(self.port, isConnect: self.isConnect.value)) }
            .store(in: &subSet)
        $usesDTRDSRFlowControl
            .removeDuplicates()
            .sink{value in
                self.port.usesDTRDSRFlowControl = value
                self.portSettings.send(PortSettings(self.port, isConnect: self.isConnect.value)) }
            .store(in: &subSet)
        $usesDCDOutputFlowControl
            .removeDuplicates()
            .sink{value in
                self.port.usesDCDOutputFlowControl = value
                self.portSettings.send(PortSettings(self.port, isConnect: self.isConnect.value)) }
            .store(in: &subSet)
        $shouldEchoReceivedData
            .removeDuplicates()
            .sink{value in
                self.port.shouldEchoReceivedData = value
                self.portSettings.send(PortSettings(self.port, isConnect: self.isConnect.value)) }
            .store(in: &subSet)
        $rts
            .removeDuplicates()
            .sink{value in
                self.port.rts = value
                self.portSettings.send(PortSettings(self.port, isConnect: self.isConnect.value)) }
            .store(in: &subSet)
        $dtr
            .removeDuplicates()
            .sink{value in
                self.port.dtr = value
                self.portSettings.send(PortSettings(self.port, isConnect: self.isConnect.value)) }
            .store(in: &subSet)
        $numberOfDataBits
            .removeDuplicates()
            .map{UInt($0)}
            .sink{value in
                self.port.numberOfDataBits = value
                self.portSettings.send(PortSettings(self.port, isConnect: self.isConnect.value)) }
            .store(in: &subSet)
        
        $allowsNonStandardBaudRates
            .removeDuplicates()
            .sink{ value in
                self.port.allowsNonStandardBaudRates = value
                self.portSettings.send(PortSettings(self.port,isConnect: self.isConnect.value))}
            .store(in: &subSet)
        
    
    }
    
    func initNotificationSub(){
        isConnect
            .removeDuplicates()
            .sink{ self.portSettings.send(PortSettings(self.port, isConnect: $0)) }
            .store(in: &subSet)
        
        isOpen
            .removeDuplicates()
            .sink{_ in self.portSettings.send(PortSettings(self.port, isConnect: self.isConnect.value)) }
            .store(in: &subSet)
        
        NotificationCenter.default
            .publisher(for: NSNotification.Name.ORSSerialPortsWereConnected)
            .sink() { notification in
                if let userInfo = notification.userInfo {
                    let connectedPorts = userInfo[ORSConnectedSerialPortsKey] as! [ORSSerialPort]
                    if  let  _ = connectedPorts.first(where: { x in x.path.elementsEqual(self.port.path) }){
                        self.isConnect.send(true)
                    }
                }
            }
            .store(in: &self.subSet)
        
        NotificationCenter.default
            .publisher(for: NSNotification.Name.ORSSerialPortsWereDisconnected)
            .sink() { notification in
                if let userInfo = notification.userInfo {
                    let disconnectedPorts: [ORSSerialPort] = userInfo[ORSDisconnectedSerialPortsKey] as! [ORSSerialPort]
                    if let _ = disconnectedPorts.first(where: { x in x.path.elementsEqual(self.port.path) }){
                        self.isConnect.send(false)
                        self.isOpen.send(false)
                    }
                }
            }
            .store(in: &self.subSet)
    }
    
    func initKVOSub(){
        
        port.publisher(for: \.cts)
            .sink{ _ in self.portSettings.send(PortSettings(self.port,isConnect: self.isConnect.value))}
            .store(in: &subSet)
        port.publisher(for: \.dsr)
            .sink{ _ in self.portSettings.send(PortSettings(self.port,isConnect: self.isConnect.value))}
            .store(in: &subSet)
        port.publisher(for: \.dcd)
            .sink{ value in self.portSettings.send(PortSettings(self.port,isConnect: self.isConnect.value))}
            .store(in: &subSet)
        port.publisher(for: \.rts)
            .sink{value in
                if (self.rts != value){
                    self.rts = value
                    self.portSettings.send(PortSettings(self.port,isConnect: self.isConnect.value))
                }}
            .store(in: &subSet)
        port.publisher(for: \.dtr)
            .sink{ value in
                if(self.dtr != value){
                    self.portSettings.send(PortSettings(self.port,isConnect: self.isConnect.value))
                    self.dtr = value }
            }
            .store(in: &subSet)
        
//        port.publisher(for: \.pendingRequest)
//            .sink{ value in self.pendingRequest = value }
//            .store(in: &subSet)
//        port.publisher(for: \.queuedRequests)
//            .sink{ value in self.queuedRequests = value }
//            .store(in: &subSet)
    }
    
}

extension ORSSerialPortCombine: ORSSerialPortDelegate{
    
    func serialPortWasRemovedFromSystem(_ serialPort: ORSSerialPort){
        isConnect.send(false)
        isOpen.send(false)
    }
    
    func serialPort(_ serialPort: ORSSerialPort, didReceive data: Data){
        receiveData.send(data)
    }
    
    func serialPort(_ serialPort: ORSSerialPort, didReceivePacket packetData: Data, matching descriptor: ORSSerialPacketDescriptor){
        receivePacket.send((packetData,descriptor))
    }
    
    func serialPort(_ serialPort: ORSSerialPort, didReceiveResponse responseData: Data, to request: ORSSerialRequest){
        self.responseData.send((responseData, request))
    }
    
    func serialPort(_ serialPort: ORSSerialPort, requestDidTimeout request: ORSSerialRequest){
        requestTimeout.send(request)
    }
    
    func serialPort(_ serialPort: ORSSerialPort, didEncounterError error: Error){
        self.error.send(error)
    }
    
    func serialPortWasOpened(_ serialPort: ORSSerialPort){
        isOpen.send(true)
    }
    
    func serialPortWasClosed(_ serialPort: ORSSerialPort){
        isOpen.send(false)
    }
    
}





extension ORSSerialPortParity {
    static func allCases() -> [ORSSerialPortParity] { [.none,.odd,.even] }
    func description() -> String {
        switch self {
            case .none: return "None"
            case .odd: return "Odd"
            case .even: return "Even"
            @unknown default: return "@unknown"
        }
    }
}

