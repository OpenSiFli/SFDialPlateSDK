import CoreBluetooth

@objc protocol SFDialPlateShellSearchDelegate {
    /// 发现了外设
    func dialPlateShell(shell:SFDialPlateShell,didDiscover peripheral:CBPeripheral)
}

@objc protocol SFDialPlateShellDelegate {

    /// 蓝牙状态改变。可通过此回调判断当前蓝牙是否可用。
    func dialPlateShell(shell: SFDialPlateShell, didUpdateState state: DPBleCoreManagerState)
    
    /// 连接失败或者断开了连接
    func dialPlateShell(shell:SFDialPlateShell, failedToConnect peripheral:CBPeripheral,error:SFError)
    
    /// 连接成功回调
    ///
    /// - Parameters:
    ///   - shell: SFDialPlateShell对象
    ///   - periperal: 成功链接的外设
    ///   - handShaked: false: 只建立链接，不会进行读写特征的搜索; true: 会进行读写特征的搜索
    func dialPlateShell(shell:SFDialPlateShell,successToConnect peripheral:CBPeripheral,handShaked:Bool)
    
    /// 设备主动上报的信息，只有Shell工作在'非RawBLEData'模式下才会触发此回调
    ///
    /// - Parameters:
    ///   - shell: SFDialPlateShell
    ///   - msgModel: 通过该对象的类型，判断设备发来了何种数据。详细对象类型见Demo或文档。
    func dialPlateShell(shell:SFDialPlateShell, recieved devRsp:SFResponseBaseModel)
}

class SFDialPlateShell: NSObject,QBleCoreDelegate,BaseTaskDelegate {

    
    /// 获取QBleOTAShell单例
    @objc static let sharedInstance = SFDialPlateShell()
    
    /// 当前已经连接或正在连接的设备
    @objc var currentPeripheral:CBPeripheral?{
        get{
            return bleCore.tempPeripheral
        }
    }
    
    @objc weak var delegate:SFDialPlateShellDelegate?
    @objc weak var searchDelegate:SFDialPlateShellSearchDelegate?
    
    
    /// 是否已经握手。只有为true时，才能通过SDK提供的QBleBaseTask的子类与设备进行蓝牙交互。否则任务会直接回调失败。
    @objc var isShakedHands:Bool{
        return bleCore.isShakedHands
    }
    
    /// 是否已经建立GATT连接。是isShakeHands的前置条件。
    @objc  var isConnected:Bool{
        return bleCore.isConnected
    }
    
    /// 当前的蓝牙状态
    @objc  var state:DPBleCoreManagerState{
        return bleCore.state
    }
    

    /// 进行蓝牙连接时的连接超时时间。默认20s
    @objc  var connectingTimeout:Double{
        set{
            bleCore.timeout = newValue
        }
        get{
            return bleCore.timeout
        }
    }
    
    private var mtu:Int?
    
    private var bleCore = QBleCore.sharedInstance
    
    private var taskArray = Array<SFDialPlateBaseTask>.init()
    
    
    /// 获取当前已经配对的设备列表。
    @objc  func retrievePairedPeripherals() -> [CBPeripheral]{

        return bleCore.retrievePairedPeripherals()
        
    }
    
    
    /// 开始搜索设备。搜索结果将通过QBleOTAShellSearchDelegate代理回调。注意：已经配对的设备可能不再广播消息，所以在QBleOTAShellSearchDelegate无法获取，因此需要使用retrievePairedPeripherals()方法来获取。
    ///
    /// - Parameter withServicesFilter: 是否对设备进行过滤。注意：当需要搜索已经进入DFU模式的设备时，应选择false。
    @objc  func startScan(withServicesFilter:Bool){
        bleCore.startScan(withServicesFilter: withServicesFilter)
    }
    
    
    /// 停止外设的搜索
    @objc  func stopScan(){
        bleCore.stopScan()
    }
    
    /// 连接设备
    ///
    /// - Parameters:
    ///   - peripheral: 通过QBleOTAShellSearchDelegate回调获得或者通过retrievePairedPeripherals()获得的外设对象。
    ///   - withShakehands: 是否进行握手连接。true-需要握手，连接成功后可以通过，提供的QBleBaseTask的子类进行蓝牙交互；false-不需要握手(仅建立GATT连接)，连接成功后无法通过提供的QBleBaseTask子类进行蓝牙交互，一般只在连接已经进入DFU模式的设备时使用。
    @objc func connect(peripheral:CBPeripheral,withShakehands:Bool){
        bleCore.connect(peripheral: peripheral, withShakeHands: withShakehands, withNotify: true)
    }
    
    
    /// 断开当前连接。
    @objc func cancelConnection(){
        bleCore.cancelConnection()
    }
    
    
    @objc func resume(task:SFDialPlateBaseTask){
        // 判断任务是否已经在队列中
        if taskArray.contains(task) {
            return
        }
        
        if isShakedHands == false {
            
            let error = SFError.init()
            error.errType = .NoConnection
            error.errInfo = "蓝牙未连接"
            task.baseCompletion?(error,nil)
            return
        }
        

        if task.baseCompletion != nil {
            // 纳入队列管理
            taskArray.append(task)
            task.delegate = self
            task.startTimer()
        }

        let msgData = task.toMsgData()//task.toPacks(mtu: self.mtu!)
        let transPacks = SFSerialTransportPack.Packs(mtu: self.mtu!, msgData: msgData)
        for p in transPacks {
            let bleData = p.marshal()
            bleCore.writeValueForWriteCharateristic(value: bleData)
        }
    }
    
    
    /// 清除所有任务，被清除的任务不产生回调
    /// 用于暂停发送时使用
    func clearAllTasks() {
        for task  in self.taskArray {
            task.stopTimer()
        }
        self.taskArray.removeAll()
    }
    
        
    func baseTaskTimeout(task: SFDialPlateBaseTask) {
        let error = SFError.init()
        error.errType = .Timeout
        error.errInfo = "任务超时(\(task.timeout)s)"
        task.baseCompletion?(error,nil)
        if let index = taskArray.firstIndex(of: task){
            taskArray.remove(at: index)
        }
    }
        
    private override init() {
        super.init()
        bleCore.delegate = self
    }
        
    
    /// QBleCore代理
    
    /// 蓝牙状态改变
    func bleCore(core: QBleCore, didUpdateState state: DPBleCoreManagerState) {
        delegate?.dialPlateShell(shell: self, didUpdateState: state)
    }
    
    /// 发现了外设
    func bleCore(core:QBleCore,didDiscover peripheral:CBPeripheral){
        if let name = peripheral.name,name.contains("SIFLI_BLE") {
            print("SIFLI_BLE.id:\(peripheral.identifier.uuidString)")
        }
        searchDelegate?.dialPlateShell(shell: self, didDiscover: peripheral)
    }
    /// 连接失败
    func bleCore(core:QBleCore, failedToConnectPeripheral peripheral:CBPeripheral,error:SFError){

        for tsk in taskArray {
            tsk.stopTimer()
            let error = SFError.init()
            error.errType = .Disconnected
            error.errInfo = "蓝牙已断开"
            tsk.baseCompletion?(error,nil)
        }
        taskArray.removeAll()
        delegate?.dialPlateShell(shell: self, failedToConnect: peripheral, error: error)
    }
    /// 连接成功
    func bleCore(core: QBleCore, successToConnect peripheral: CBPeripheral, handeShaked: Bool) {

        let sysMTU = currentPeripheral!.maximumWriteValueLength(for: .withoutResponse)
        if sysMTU > 247 {
            QPrint("⚠️获取到MTU(\(sysMTU))大于247，强制设为247")
            self.mtu = 247
        }else{
            QPrint("✅获取到MTU:\(sysMTU)")
            self.mtu = sysMTU
        }
        delegate?.dialPlateShell(shell: self, successToConnect: peripheral, handShaked: handeShaked)
    }
    
    
    func bleCore(core: QBleCore, didWriteValue writeCharacteristic: CBCharacteristic, error: Error?) {
        guard let err = error else{
            return
        }
        QPrint("写入蓝牙数据时发生错误,\(err)")
    }

    /// 收到数据
    func bleCore(core:QBleCore,characteristic:CBCharacteristic,didUpdateValue value:Data){
        // 每次收到的数据都是完整的一条
        if value.count < 8 {
            QPrint("⚠️⚠️⚠️收到设备发来小于4字节的数据:\(NSData.init(data: value).debugDescription)")
            return
        }
        let msgData = NSData.init(data: value[4..<value.count])
        var cmdValue:UInt16 = 0
        msgData.getBytes(&cmdValue, range: NSRange.init(location: 0, length: 2))
        
        guard let cmd = SFDialPlateCMD.init(rawValue: cmdValue) else{
            QPrint("⚠️未知的响应cmd=\(cmdValue)")
            return
        }
        
        let restData = msgData.subdata(with: NSRange.init(location: 2, length: msgData.count-2))
        
        let rspBaseModel = SFResponseBaseModel.init(cmd: cmd, data: restData)
        
        var pairedReqTask:SFDialPlateBaseTask?
        for task in taskArray{
            if SFCmdsTools.IsPaired(requestCmd: task.cmd, responseCmd: rspBaseModel.cmd){
                pairedReqTask = task
                break
            }
        }
        
        if let t = pairedReqTask{
            t.stopTimer()
            if let index = taskArray.firstIndex(of: t){
                taskArray.remove(at: index)
            }
            t.baseCompletion?(nil, rspBaseModel)
        }else{
            delegate?.dialPlateShell(shell: self, recieved: rspBaseModel)
        }
    }
}

