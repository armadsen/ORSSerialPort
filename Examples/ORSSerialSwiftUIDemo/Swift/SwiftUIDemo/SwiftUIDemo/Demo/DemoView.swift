//
//  SerialPortSettingView.swift
//  SerialPort
//
//  Created by Jan Anstipp on 30.09.20.
//

import SwiftUI
import ORSSerial

struct DemoView: View{
    @ObservedObject var viewM: ViewModel
    var debug: Bool = false
    var body: some View{
        HStack{
            VStack{
                HStack{
                    Text("Port")
                    Picker("", selection: $viewM.path){
                        ForEach(viewM.availablePorts , id: \.self) {
                            Text($0)
                        }
                    }.frame(width: 200)
                }
                .padding(.trailing, 8)
                .padding(.leading, 70)
                
                if let serialPort = viewM.serialPort{
                    PortSettingView(viewM: viewM, serialP: serialPort)
                }
                
            }.frame(minWidth: 500, maxWidth: .infinity, minHeight: 800, idealHeight: 800, maxHeight: .infinity, alignment: .center)
            //Debuggin
            if debug{
                SettingsView(settings: $viewM.settings)
                SettingsView(settings: $viewM.settingsDebug)
                Button("Update", action: { self.viewM.updatePortTestSetting()})
            }
        }
    }
}

struct PortSettingView: View{
    @ObservedObject var viewM: ViewModel
    @ObservedObject var serialP: ORSSerialPortCombine
    
    @State private var isAdd: Bool = false
    @State private var suffix: Suffix = .none
    @State private var command: String = ""
    var body: some View {
        VStack{
            //====== Port Settings ======
            VStack{
                HStack(alignment: .top){
                    VStack(alignment: .trailing ){
                        Text("Bautrate")
                        Text("StopBits").padding([.top], 14)
                        Text("Parity").padding([.top], 14)
                    }
                    VStack(alignment: .leading){
                        Picker("", selection: $serialP.baudRate){
                            ForEach(BaudRate.allCases, id: \.value) {
                                Text(String($0.value))
                            }
                        }
                        Picker("", selection: $serialP.numberOfStopBits){
                            ForEach([1,2], id: \.self) {
                                Text(String($0))
                            }
                        }
                        .frame(width: 70)
                        .pickerStyle(SegmentedPickerStyle())
                        
                        Picker("", selection: $serialP.parity){
                            ForEach(ORSSerialPortParity.allCases(), id: \.self) {
                                Text($0.description())
                            }
                        }
                        .frame(width: 160)
                        .pickerStyle(SegmentedPickerStyle())
                    }.frame(width: 200)
                    Button(viewM.settings.isOpen ? "Close" : "Open") { viewM.settings.isOpen ? serialP.close() : serialP.open() }
                }
            }
            .alignmentGuide( HorizontalAlignment.center, computeValue: { d in
                return ( d[HorizontalAlignment.center] - 50)
            })
            
            //====== Intput Output ======
            Divider()
            VStack{
                Text("Input     OutPut")
                    .alignmentGuide(HorizontalAlignment.center, computeValue: { dimension in
                        dimension[HorizontalAlignment.center] - 55
                    })
                HStack(alignment: .top){
                    Text("Flow Controll")
                    
                    VStack(alignment:.leading){
                        Toggle("RTS/CTS", isOn: $serialP.usesRTSCTSFlowControl).padding([.top,.bottom], 1)
                        Toggle("DTR/DSR", isOn: $serialP.usesDTRDSRFlowControl).padding([.top,.bottom], 1)
                        Toggle("DCD", isOn: $serialP.usesDCDOutputFlowControl).padding([.top,.bottom], 1)
                        Toggle("Echo", isOn: $serialP.shouldEchoReceivedData).padding([.top,.bottom], 1)
                    }
                }
                
            }
            .alignmentGuide( HorizontalAlignment.center, computeValue: { d in
                return ( d[HorizontalAlignment.center] + 45)
            })
            
            
            //====== Terminal ======
            Divider()
            
            HStack{
                TextField("", text: $command )
                Button("Send", action: { serialP.send(value: command, suffix: (isAdd ? suffix.value : "")) })
                Toggle(isOn: $isAdd , label: { Text("Add") })
                
                Picker("", selection: $suffix){
                    ForEach(Suffix.allCases, id: \.self) { x in
                        Text(x.description)
                    }
                }.frame(width: 110)
            }.padding()
            
            Divider()
            VStack(alignment: .leading){
                Button("Clear", action: {
                    
                })
                ScrollView{
                    TextField("", text: $viewM.recieve )
                        .multilineTextAlignment(.leading)
                }
                
            }
            .frame(minHeight: 200, idealHeight: 300, maxHeight: .infinity)
            .padding()
            
            //====== Output Input ======
            
            HStack{
                Text("PinState").padding(.top, 25)
                    .padding([.leading,.trailing], 10)
                VStack{
                    Text("Output")
                    HStack{
                        Toggle("RTS", isOn: $serialP.rts)
                        Toggle("DTR", isOn: $serialP.dtr)
                    }
                    
                }.padding([.leading,.trailing], 20)
                VStack{
                    Text("Input")
                    HStack{
                        Toggle("CTS", isOn: $viewM.settings.cts).disabled(true)
                        Toggle("DSR", isOn: $viewM.settings.dsr).disabled(true)
                        Toggle("DCD", isOn: $viewM.settings.dcdIn).disabled(true)
                    }
                }.padding([.leading,.trailing], 20)
            }.frame(width: 500)
            
            //====== fooder ======
            Divider()
            HStack{
                Spacer()
                Text(viewM.settings.name)
                Text("Baudrate: "+String(serialP.baudRate))
                Text(viewM.settings.isConnect ? "Device: Connect" : "Device: Disconect")
                Text(viewM.settings.isOpen ? "Port: Open" : "Port: Close")
                
            }
            
        }
    }
}

struct SettingsView: View {
    @Binding var settings: PortSettings
    var body: some View{
        
        HStack{
            
            VStack(alignment: .trailing){
                Text("path")
                Text("name")
                Text("baudRate")
                Text("Stopbits")
                Text("parity")
                Text("rts/cts")
                Group{
                    Text("dtr/dsr")
                    Text("dcd")
                    Text("echo")
                    Text("rts")
                    Text("dtr")
                    Text("cts")
                    Text("dsr")
                    Text("dcd")
                    Text("port")
                    Text("device")
                }
            }
            VStack(alignment: .leading){
                Text(settings.path)
                Text(settings.name)
                Text(settings.baudRate.description)
                Text(String(settings.numberOfStopBits))
                Text(settings.parity.description())
                Text(settings.usesRTSCTSFlowControl ? "on" : "off")
                Group{
                    Text(settings.usesDTRDSRFlowControl ? "on" : "off")
                    Text(settings.usesDCDOutputFlowControl ? "on" : "off")
                    Text(settings.echo ? "on" : "off")
                    Text(settings.rts ? "on" : "off")
                    Text(settings.dtr ? "on" : "off")
                    Text(settings.cts ? "on" : "off")
                    Text(settings.dsr ? "on" : "off")
                    Text(settings.dcdIn ? "on" : "off")
                    Text(settings.isOpen ? "open" : "close")
                    Text(settings.isConnect ? "connect" : "disconnect")
                }
            }
        }
        
    }
}


struct PortSelectionView_Previews: PreviewProvider {
    static let viewM = ViewModel()
    static var previews: some View {
        DemoView(viewM: viewM)
    }
}

struct SettingView_Previews: PreviewProvider {
    @State static var port = PortSettings()
    static var previews: some View {
        SettingsView(settings: $port)
            .frame(width: 300, height: 300, alignment: .center)
    }
}

//You need change the URL if you will see this Preview.
struct PortSettingView_Previews: PreviewProvider {
    static let viewM = ViewModel()
    static let port = ORSSerialPortCombine("/dev/cu.usbmodem143201")!
    
    static var previews: some View {
        PortSettingView(viewM: viewM, serialP: port)
    }
}

enum Suffix: CaseIterable{
    case cr
    case lf
    case crls
    case none
    
    var description: String {
        switch self {
            case .cr: return "CR (\\r}"
            case .lf: return "LF (\\n)"
            case .crls: return "CRLF (\\r\\n)"
            case .none: return "none"
        }
    }
    var value: String {
        switch self {
            case .cr: return "\r"
            case .lf: return "\n"
            case .crls: return "\r\n)"
            case .none: return ""
        }
    }
}

enum BaudRate: CaseIterable{
    case _300
    case _1200
    case _2400
    case _4800
    case _9600
    case _14400
    case _19200
    case _28800
    case _38400
    case _57600
    case _115200
    case _230400
    
    var value: Int{
        switch(self){
            case ._300: return 300
            case ._1200: return 1200
            case ._2400: return 2400
            case ._4800: return 4800
            case ._9600: return 9600
            case ._14400: return 14400
            case ._19200: return 19200
            case ._28800: return 28800
            case ._38400: return 38400
            case ._57600: return 57600
            case ._115200: return 115200
            case ._230400: return 230400
        }
    }
}
