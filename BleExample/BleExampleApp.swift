//
//  Welcome to the Witte Smart Bluetooth 5.0 sample program
//  1. For your convenience, this program has only this code file
//  2. This program is suitable for Witte Smart Bluetooth 5.0 inclination sensor
//  3. This program will demonstrate how to obtain sensor data and control the sensor
//  4. If you have any questions, you can check the program supporting documentation, or consult our technical staff
//
//  Created by huangyajun on 2022/8/26.
//

/*
// **************************************************************
GAIT APP DESIGN - ESTY

 Outline of Code for Feedback from an IMU.
 
 *) Goal is to calculate the mean amplitude of all frequencies of a sample of the summed X, Y and Z vectors. This requires calculating the amplitude of all frequencies within the samples(using a FFT), taking the mean and summing the three values.The variables used to access the data are AccX, AccY and AccZ. This links to a description of the study:
 https://www.brianesty.com/bodywork/2023/10/evaluating-how-we-interact-with-gravity/
 *) This calculated value describes the relative total energy used within a movement. From testing it is observed that energy can be "spilled" in all three vectors. I am reaching for a metric for efficiency or optimization in movement.
 *) If this value is displayed on a watch, and/or with haptic/audio feedback when a threshold is crossed, it provides dynamic feedback for the optimization or efficiency of movement, training both meurology and physiology. The relevance of this information has a very short lifespan, in the range of 1-2 seconds, requiring a quick feedback loop.
*) An example of the application is to continually sample the three IMU acceleration readings. Every second the three arrays are processed (FFT, then Mean, then summed. 1 sec = 50 readings). The value can then be compared to a threshold value set in the UI. If true, then a haptic/audio alert is triggered. This facilitates training on routine/repetitive actions. More advanced options could use stored values and even reference changes in location using GPS.

 *******************************
 Questions:
 *) figure out the function of the 03 register (this is a button on the UI). No documentation found and the button does not seem to do anything.

 Notes:
 *) Default sample rate is 20 msec which seems about right.
 *) The raw accel data is souced from BWT901BLE5_0DataProcessor as regAx etc. It is converted into gravitational units before output to the UI as AccX etc.
 *) Intitial studies have benn done using a discrete IMU on the midline. However, once this is built, a version using the embedded IMU within the phone could be studied as initial results suggest that efficiency in all three vectors tightly correlates and that the position of the IMU on the body may be less critical than assumed.
***************************************************************
*/

import SwiftUI
import CoreBluetooth
import WitSDK
import Accelerate
import Foundation


// **********************************************************
// MARK: App main view
// **********************************************************
@main
struct AppMainView : App {
    
    // MARK: tab page enumeration
    enum Tab {
        case connect
        case home
    }
    
    // MARK: The currently selected tab page
    @State private var selection: Tab = .home
    
    // MARK: App the context
    var appContext:AppContext = AppContext()
    
    // MARK: UI Page
    var body: some Scene {
        WindowGroup {
            if (UIDevice.current.userInterfaceIdiom == .phone){
                TabView(selection: $selection) {
                    NavigationView {
                        ConnectView(appContext)
                            
                    }
                    .tabItem {
                        Label {
                            Text("连接设备 Connect the device", comment: "在这连接设备 Connect device here")
                        } icon: {
                            Image(systemName: "list.bullet")
                        }
                    }
                    .tag(Tab.connect)
                    
                    NavigationView {
                        HomeView(appContext)
                    }
                    .tabItem {
                        Label {
                            Text("设备数据 device data", comment: "在这查看设备的数据 View device data here")
                        } icon: {
                            Image(systemName: "heart.fill")
                        }
                    }
                    .tag(Tab.connect)
                }
            } else {
                NavigationView{
                    List{
                        NavigationLink() {
                            ConnectView(appContext)
                        } label: {
                            Label("连接设备 Connect the device", systemImage: "list.bullet")
                        }
                        
                        NavigationLink() {
                            HomeView(appContext)
                        } label: {
                            Label("主页面 main page", systemImage: "heart")
                        }
                    }
                }
            }
        }
    }
}


// **********************************************************
// MARK: App the context
// **********************************************************
class AppContext: ObservableObject ,IBluetoothEventObserver, IBwt901bleRecordObserver{
    
    // Get bluetooth manager
    var bluetoothManager:WitBluetoothManager = WitBluetoothManager.instance
    
    // Whether to scan the device
    @Published
    var enableScan = false
    
    // Bluetooth 5.0 sensor object
    @Published
    var deviceList:[Bwt901ble] = [Bwt901ble]()
    
    // Device data to display
    @Published
    var deviceData:String = "device not connected"
    
    init(){
        // Current scan status
        self.enableScan = self.bluetoothManager.isScaning
        // start auto refresh thread
        startRefreshThread()
    }
    
    // MARK: Start scanning for devices
    func scanDevices() {
        print("Start scanning for surrounding bluetooth devices")
        // Remove all devices, here all devices are turned off and removed from the list
        removeAllDevice()
        // Registering a Bluetooth event observer
        self.bluetoothManager.registerEventObserver(observer: self)
        // Turn on bluetooth scanning
        self.bluetoothManager.startScan()
    }
    
    // MARK: This method is called if a Bluetooth Low Energy sensor is found
    func onFoundBle(bluetoothBLE: BluetoothBLE?) {
        if isNotFound(bluetoothBLE) {
            print("\(String(describing: bluetoothBLE?.peripheral.name)) found a bluetooth device")
            self.deviceList.append(Bwt901ble(bluetoothBLE: bluetoothBLE))
        }
    }
    
    // Judging that the device has not been found
    func isNotFound(_ bluetoothBLE: BluetoothBLE?) -> Bool{
        for device in deviceList {
            if device.mac == bluetoothBLE?.mac {
                return false
            }
        }
        return true
    }
    
    // MARK: You will be notified here when the connection is successful
    func onConnected(bluetoothBLE: BluetoothBLE?) {
        print("\(String(describing: bluetoothBLE?.peripheral.name)) 连接成功")
    }
    
    // MARK: Notifies you here when the connection fails
    func onConnectionFailed(bluetoothBLE: BluetoothBLE?) {
        print("\(String(describing: bluetoothBLE?.peripheral.name)) ")
    }
    
    // MARK: You will be notified here when the connection is lost
    func onDisconnected(bluetoothBLE: BluetoothBLE?) {
        print("\(String(describing: bluetoothBLE?.peripheral.name)) 连接断开")
    }
    
    // MARK: Stop scanning for devices
    func stopScan(){
        self.bluetoothManager.removeEventObserver(observer: self)
        self.bluetoothManager.stopScan()
    }
    
    // MARK: Turn on the device
    func openDevice(bwt901ble: Bwt901ble?){
        print(" MARK: Turn on the device")
        
        do {
            try bwt901ble?.openDevice()
            // Monitor data
            bwt901ble?.registerListenKeyUpdateObserver(obj: self)
        }
        catch{
            print("Failed to open device")
        }
    }
    
    // MARK: Remove all devices
    func removeAllDevice(){
        for item in deviceList {
            closeDevice(bwt901ble: item)
        }
        deviceList.removeAll()
    }
    
    // MARK: Turn off the device
    func closeDevice(bwt901ble: Bwt901ble?){
        print("Turn off the device")
        bwt901ble?.closeDevice()
    }
    
    // MARK: You will be notified here when data from the sensor needs to be recorded
    func onRecord(_ bwt901ble: Bwt901ble) {
        // You can get sensor data here
        let deviceData =  getDeviceDataToString(bwt901ble)
        // Prints to the console, where you can also log the data to your file
        print(deviceData)
    }
    
    // MARK: Enable automatic execution thread
    func startRefreshThread(){
        // start a thread
        let thread = Thread(target: self,
                            selector: #selector(refreshView),
                            object: nil)
        thread.start()
    }
    
    // MARK: Refresh the view thread, which will refresh the sensor data displayed on the page here
    @objc func refreshView (){
        // Keep running this thread
        while true {
            // Refresh 5 times per second
            Thread.sleep(forTimeInterval: 1 / 5)
            // Temporarily save sensor data
            var tmpDeviceData:String = ""
            // Print the data of each device
            for device in deviceList {
                if (device.isOpen){
                    // Get the data of the device and concatenate it into a string
                    let deviceData =  getDeviceDataToString(device)
                    tmpDeviceData = "\(tmpDeviceData)\r\n\(deviceData)"
                }
            }
            
            // Refresh ui
            DispatchQueue.main.async {
                self.deviceData = tmpDeviceData
            }
            
        }
    }
    
    // MARK: Get the data of the device and concatenate it into a string
    func getDeviceDataToString(_ device:Bwt901ble) -> String {
        var s = ""
        /*        s  = "\(s)name:\(device.name ?? "")\r\n"
        s  = "\(s)mac:\(device.mac ?? "")\r\n"
        s  = "\(s)version:\(device.getDeviceData(WitSensorKey.VersionNumber) ?? "")\r\n" */
        s  = "\(s)AX:\(device.getDeviceData(WitSensorKey.AccX) ?? "") g\r\n"
        s  = "\(s)AY:\(device.getDeviceData(WitSensorKey.AccY) ?? "") g\r\n"
        s  = "\(s)AZ:\(device.getDeviceData(WitSensorKey.AccZ) ?? "") g\r\n"
/*        s  = "\(s)GX:\(device.getDeviceData(WitSensorKey.GyroX) ?? "") °/s\r\n"
        s  = "\(s)GY:\(device.getDeviceData(WitSensorKey.GyroY) ?? "") °/s\r\n"

        if let accYString = device.getDeviceData(WitSensorKey.AccY), let accY = Double(accYString) {
            // Call updateAccYData with the extracted AccY value
            updateAccYData(newAccY: accY)
        }
*/
        /*        s  = "\(s)GZ:\(device.getDeviceData(WitSensorKey.GyroZ) ?? "") °/s\r\n"
        s  = "\(s)AngX:\(device.getDeviceData(WitSensorKey.AngleX) ?? "") °\r\n"
        s  = "\(s)AngY:\(device.getDeviceData(WitSensorKey.AngleY) ?? "") °\r\n"
        s  = "\(s)AngZ:\(device.getDeviceData(WitSensorKey.AngleZ) ?? "") °\r\n"
        s  = "\(s)HX:\(device.getDeviceData(WitSensorKey.MagX) ?? "") μt\r\n"
        s  = "\(s)HY:\(device.getDeviceData(WitSensorKey.MagY) ?? "") μt\r\n"
        s  = "\(s)HZ:\(device.getDeviceData(WitSensorKey.MagZ) ?? "") μt\r\n"
        s  = "\(s)Electric:\(device.getDeviceData(WitSensorKey.ElectricQuantityPercentage) ?? "") %\r\n"
        s  = "\(s)Temp:\(device.getDeviceData(WitSensorKey.Temperature) ?? "") °C\r\n"  */
        return s
    }

/*     //FIND DOMINANT FREQUENCY CODE FROM CHAT GPT - Brian

 var accYData: [Double] = []

 // Assume updateAccYData() is called every time new AccY data is available
 func updateAccYData(newAccY: Double) {
     if accYData.count < 100 {
         accYData.append(newAccY)
     } else {
         accYData.removeFirst()
         accYData.append(newAccY)
         performFFT()
         print("Data collected, performing FFT") // Debug print
     }
 }
 
    func performFFT() {
        func performFFT() {
            var inReal = accYData
            var inImag = [Double](repeating: 0.0, count: inReal.count)
            
            inReal.withUnsafeMutableBufferPointer { inRealBuffer in
                inImag.withUnsafeMutableBufferPointer { inImagBuffer in
                    guard let inRealPtr = inRealBuffer.baseAddress, let inImagPtr = inImagBuffer.baseAddress else { return }
                    
                    var inComplex = DSPDoubleSplitComplex(realp: inRealPtr, imagp: inImagPtr)
                    
                    let length = vDSP_Length(log2(Double(inRealBuffer.count)))
                    guard let fftSetup = vDSP_create_fftsetupD(length, FFTRadix(kFFTRadix2)) else { return }
                    
                    // Use local arrays for the output.
                    var outReal = [Double](repeating: 0.0, count: inRealBuffer.count)
                    var outImag = [Double](repeating: 0.0, count: inImagBuffer.count)
                    
                    outReal.withUnsafeMutableBufferPointer { outRealBuffer in
                        outImag.withUnsafeMutableBufferPointer { outImagBuffer in
                            guard let outRealPtr = outRealBuffer.baseAddress, let outImagPtr = outImagBuffer.baseAddress else { return }
                            
                            var outComplex = DSPDoubleSplitComplex(realp: outRealPtr, imagp: outImagPtr)
                            
                            vDSP_fft_zopD(fftSetup, &inComplex, 1, &outComplex, 1, length, FFTDirection(kFFTDirection_Forward))
                            
                            vDSP_destroy_fftsetupD(fftSetup)
                            
                            // Assuming you have a function to find the dominant frequency.
                            findDominantFrequency(real: outReal, imag: outImag)
                        }
                    }
                }
            }
        }






    func findDominantFrequency(real: [Double], imag: [Double]) {
        var magnitudes = [Double](repeating: 0.0, count: real.count)
        
        var real = real
        var imag = imag
        var complex = DSPDoubleSplitComplex(realp: &real, imagp: &imag)
        
        vDSP_zvmagsD(&complex, 1, &magnitudes, 1, vDSP_Length(real.count))
        
        if let maxIndex = magnitudes.indices.max(by: { magnitudes[$0] < magnitudes[$1] }) {
            let dominantFrequency = Double(maxIndex) * 50 / Double(real.count) // 50 is the speculated sample rate
            print("Dominant Frequency: \(dominantFrequency) Hz")
        }
    }

*/

/* From GPT 4
    func loadCSVData(fileURL: URL) -> [Double]? {
        do {
            let data = try String(contentsOf: fileURL, encoding: .utf8)
            let values = data.split(separator: "\n").map { Double($0)! }
            return values
        } catch {
            print("Error: \(error)")
            return nil
        }
    }

    func performFFT(input: [Double]) -> [Double] {
        var real = input
        var imaginary = [Double](repeating: 0.0, count: input.count)
        var splitComplex = DSPDoubleSplitComplex(realp: &real, imagp: &imaginary)
        
        let length = vDSP_Length(floor(log2(Double(input.count)))))
        let radix = FFTRadix(kFFTRadix2)
        let weights = vDSP_create_fftsetupD(length, radix)
        
        vDSP_fft_zipD(weights!, &splitComplex, 1, length, FFTDirection(FFT_FORWARD))
        
        vDSP_destroy_fftsetupD(weights)
        
        // Compute magnitudes
        var magnitudes = [Double](repeating: 0.0, count: input.count)
        vDSP_zvabsD(&splitComplex, 1, &magnitudes, 1, vDSP_Length(input.count))
        
        return magnitudes
    }

    func findDominantFrequency(magnitudes: [Double], samplingRate: Double) -> Double {
        var max_magnitude: Double = 0.0
        var max_index: vDSP_Length = 0
        
        vDSP_maxviD(magnitudes, 1, &max_magnitude, &max_index, vDSP_Length(magnitudes.count))
        
        let dominantFrequency = Double(max_index) * samplingRate / Double(magnitudes.count)
        return dominantFrequency
    }

    // Example usage
    let fileURL = URL(fileURLWithPath: "/path_to_your_file/Ball.txt")
    if let data = loadCSVData(fileURL: fileURL) {
        let column5 = data // Or select the actual 5th column
        let magnitudes = performFFT(input: column5)
        let dominantFrequency = findDominantFrequency(magnitudes: magnitudes, samplingRate: 50.0)
        
        print("Dominant Frequency: \(dominantFrequency) Hz")
    }

*/

    // MARK: Addition calibration
    func appliedCalibration(){
        for device in deviceList {
            
            do {
                // Unlock register
                try device.unlockReg()
                // Addition calibration
                try device.appliedCalibration()
                // save
                try device.saveReg()
                
            }catch{
                print("Set failed")
            }
        }
    }
    
    // MARK: Start magnetic field calibration
    func startFieldCalibration(){
        for device in deviceList {
            do {
                // Unlock register
                try device.unlockReg()
                // Start magnetic field calibration
                try device.startFieldCalibration()
                // save
                try device.saveReg()
            }catch{
                print("Set failed")
            }
        }
    }
    
    // MARK: End magnetic field calibration
    func endFieldCalibration(){
        for device in deviceList {
            do {
                // Unlock register
                try device.unlockReg()
                // End magnetic field calibration
                try device.endFieldCalibration()
                // save
                try device.saveReg()
            }catch{
                print("设置失败 Set failed")
            }
        }
    }
    
    // MARK: Read the 03 register
    func readReg03(){
        for device in deviceList {
            do {
                // Read the 03 register and wait for 200ms. If it is not read out, you can extend the reading time or read it several times
                try device.readRge([0xff ,0xaa, 0x27, 0x03, 0x00], 200, {
                    let reg03value = device.getDeviceData("03")
                    // Output the result to the console
                    print("\(String(describing: device.mac)) reg03value: \(String(describing: reg03value))")
                })
            }catch{
                print("Set failed")
            }
        }
    }
    
    // MARK: Set 50hz postback
    func setBackRate50hz(){
        for device in deviceList {
            do {
                // unlock register
                try device.unlockReg()
                // Set 50hz postback and wait 10ms
                try device.writeRge([0xff ,0xaa, 0x03, 0x08, 0x00], 10)
                // save
                try device.saveReg()
            }catch{
                print("设置失败 Set failed")
            }
        }
    }
    
    // MARK: Set 10hz postback
    func setBackRate10hz(){
        for device in deviceList {
            do {
                // 解锁寄存器
                // unlock register
                try device.unlockReg()
                // 设置10hz回传,并等待10ms
                // Set 10hz postback and wait 10ms
                try device.writeRge([0xff ,0xaa, 0x03, 0x06, 0x00], 100)
                // 保存
                // save
                try device.saveReg()
            }catch{
                print("Set failed")
            }
        }
    }
}

// **********************************************************
// MARK: Home view start
// **********************************************************
struct HomeView: View {
    
    // App the context
    @ObservedObject var viewModel:AppContext
    
    // MARK: Constructor
    init(_ viewModel:AppContext) {
        // View model
        self.viewModel = viewModel
    }
    
    // MARK: UI page
    var body: some View {
        ZStack(alignment: .leading) {
            VStack(alignment: .center){
                HStack {
                    Text("Control device")
                        .font(.title)
                }
                HStack{
                    VStack{
                        Button("Acc cali") {
                            viewModel.appliedCalibration()
                        }.padding(10)
                        Button("Read 03 reg"){
                            viewModel.readReg03()
                        }.padding(10)
                        /* Mag cali not used
                        Button("Start mag cali"){
                            viewModel.startFieldCalibration()
                        }.padding(10)
                        Button("结束磁场校准 Stop mag cali"){
                            viewModel.endFieldCalibration()
                        }.padding(10)*/
                    }
                    VStack{
                        Button("Set 50hz rate"){
                            viewModel.setBackRate50hz()
                        }.padding(10)
                        Button("Set 10hz rate"){
                            viewModel.setBackRate10hz()
                        }.padding(10)
                    }
                }
                
                HStack {
                    Text("Device data")
                        .font(.title)
                }
                ScrollViewReader { proxy in
                    List{
                        Text(self.viewModel.deviceData)
                            .fontWeight(.bold)
                            .font(.body)
                    }
                }
            }
        }.navigationBarHidden(true)
    }
}


struct Home_Previews: PreviewProvider {
    static var previews: some View {
        HomeView(AppContext())
    }
}


// **********************************************************
// MARK: Start with the view
// **********************************************************
struct ConnectView: View {
    
    // App the context
    @ObservedObject var viewModel:AppContext
    
    // MARK: Constructor
    init(_ viewModel:AppContext) {
        // View model
        self.viewModel = viewModel
    }
    
    // MARK: UI page
    var body: some View {
        ZStack(alignment: .leading) {
            VStack{
                Toggle(isOn: $viewModel.enableScan){
                    Text("Turn on scanning for surrounding devices")
                }.onChange(of: viewModel.enableScan) { value in
                    if value {
                        viewModel.scanDevices()
                    }else{
                        viewModel.stopScan()
                    }
                }.padding(10)
                ScrollViewReader { proxy in
                    List{
                        ForEach (self.viewModel.deviceList){ device in
                            Bwt901bleView(device, viewModel)
                        }
                    }
                }
            }
        }.navigationBarHidden(true)
    }
}


struct ConnectView_Previews: PreviewProvider {
    static var previews: some View {
        ConnectView(AppContext())
    }
}

// **********************************************************
// MARK: View showing Bluetooth 5.0 sensor
// **********************************************************
struct Bwt901bleView: View{
    
    // bwt901ble instance
    @ObservedObject var device:Bwt901ble
    
    // App the context
    @ObservedObject var viewModel:AppContext
    
    // MARK: Constructor
    init(_ device:Bwt901ble,_ viewModel:AppContext){
        self.device = device
        self.viewModel = viewModel
    }
    
    // MARK: UI page
    var body: some View {
        VStack {
            Toggle(isOn: $device.isOpen) {
                VStack {
                    Text("\(device.name ?? "")")
                        .font(.headline)
                    Text("\(device.mac ?? "")")
                        .font(.subheadline)
                }
            }.onChange(of: device.isOpen) { value in
                if value {
                    viewModel.openDevice(bwt901ble: device)
                }else{
                    viewModel.closeDevice(bwt901ble: device)
                }
            }
            .padding(10)
        }
    }
}
