import UIKit
import CoreBluetooth
//import Zip
import ZIPFoundation

fileprivate let MaxFileReSendCount = 3
fileprivate let MaxLoseCheckSerialTransErrorCount = 3


@objc public protocol SFDialPlateManagerDelegate{
    
    /// 蓝牙状态发生改变时产生的回调。
    @objc func dialPlateManager(manager: SFDialPlateManager, didUpdateBLEState bleState: DPBleCoreManagerState)
        
    /// 推送进度回调。progess取值0~100
    @objc func dialPlateManager(manager: SFDialPlateManager, progress:Int)
    
    /// 推送结束回调。error为空表示推送成功，不为空表示推送失败
    @objc func dialPlateManager(manager:SFDialPlateManager,complete error:SFError?)

}

@objc public class SFDialPlateManager:NSObject, SFDialPlateShellSearchDelegate, SFDialPlateShellDelegate{

    /// 获取SFDialPlateManager单例对象
    @objc public static let share = SFDialPlateManager()
    
    @objc static public var SDKVersion:String {
        return Const_SDKVersion
    }
    
    /// 当前Manager是否正忙。为true则会忽略pushDialPlate函数的调用
    @objc public var isBusy:Bool{
        return (pushInfo != nil) || isLoadingFiles
    }
    
    private var isLoadingFiles = false
    
    
    /// 是否处于发送image阶段
    /// 主要用于收到LoseCheck消息时，进行状态判断
    private var isSendingFile = false {
        didSet{
            if oldValue != isSendingFile {
                QPrint("⚠️isSendingFile发生变化:\(oldValue) ===> \(isSendingFile)")
            }
        }
    }
    
    /// 是否处于LoseChecking状态
    private var isLoseChecking = false {
        didSet{
            if oldValue != isLoseChecking {
                QPrint("⚠️isLoseChecking发生变化:\(oldValue) ===> \(isLoseChecking)")
            }
        }
    }
    
    /// 推送过程、结果监听代理
    @objc public weak var delegate:SFDialPlateManagerDelegate?
    
    
    private let shell = SFDialPlateShell.sharedInstance
    
    
    private var pushInfo:SFPushInfos?
    private var searchTimer:Timer?
    
    // 主要用于从LoseCheck状态恢复到发送状态时
    private var currentFileIndex = 0
    
    // 一次流程中，出现3次LoseCheck携带Serial transport Error 则退出流程，并在回调信息中告知用户减小maxFileSliceLength
    private var loseCheckReceiveErrorCount = 0
    
//    private var delayRestartTimer:Timer?
    
    private var totalBytes = 0
    private var completedBytes = 0
    
    private var fileReSendCount = 0
    
    // 为nil表示还未通过“EntireStart”获取到设备版本号
    // 老设备没有版本号，但经过EntireStart后会认为版本为0
    private var deviceVersion:UInt16?
    private let cacheDirectory = "sifli_diaplate_res"
    
    private override init() {
        super.init()
        shell.delegate = self
        shell.searchDelegate = self
    }
    
    @objc private func pauseForTest() {
        QPrint("⚠️[Pause For Test]")
        self.shell.clearAllTasks()
    }
    
    @objc public func getCompleteBytes()->Int{
        return self.completedBytes;
    }
    
    @objc public func getTotalBytes()->Int{
        return self.totalBytes;
    }
    
    
    /// 推送表盘文件
    /// - Parameters:
    ///   - devIdentifier: 目标设备的identifier字符串。通过CBPeripheral.identifier.uuidString获取
    ///   - type: 文件类型。0-表盘，1-多语言，2-背景图，3-自定义，4-音乐,5-JS,8-4g模块,9-sfwatchface。其它类型查阅文档。
    ///   - zipPath: zip格式的升级文件位于本地的url
    ///   - maxFileSliceLength: 文件切片长度，默认1024字节。数值越大速度越快，但可能造成设备无法响应。该值应视具体设备而定。
    ///   - withByteAlign: 是否对文件进行CRC和字节对齐处理，需要依据具体的设备支持情况来决定该参数的取值。默认false。PS：当type为3时，总是会进行CRC和对齐操作，与该参数取值无关。当type=8 时，该参数无效，不会添加CRC和对齐
    @objc public func pushDialPlate(devIdentifier:String, type:UInt16, zipPath:URL, maxFileSliceLength:Int=1024, withByteAlign:Bool = false){
        isLoadingFiles = true
        do{
            let unzipDirectory = try CacheHelper.reCreateCacheDirectory(directory: self.cacheDirectory)
            let fileManager = FileManager()
            try fileManager.unzipItem(at: zipPath, to: unzipDirectory)
//            let unzipDirectory = try Zip.quickUnzipFile(zipPath)
//            QPrint("unzipDirectory = \(unzipDirectory)")
            let relativeFilePaths = PathUtils.RelativeFilePaths(rootPath: unzipDirectory)
            if relativeFilePaths == nil || relativeFilePaths?.count == 0{
                if (relativeFilePaths?.count) != nil {
                    QPrint("❌file count is 0!")
                }
                let err = SFError.init()
                err.errType = .InvalidFile
                err.errInfo = "invalid file"
                completionHandler(error: err)
                return
            }
            
            var fileArray = Array<SFFile>.init()
            for relativePath in relativeFilePaths!{
                let filePath = unzipDirectory.appendingPathComponent(relativePath)
                do{
                    let fileData = try Data.init(contentsOf: filePath)
                    
                    var filePathName = relativePath
                    if filePathName.starts(with: "/") == false{
                        filePathName = "/" + filePathName
                    }
                    let file = SFFile.init(fileName: filePathName, file: fileData)
                    fileArray.append(file)
                }catch{
                    try? FileManager.default.removeItem(at: unzipDirectory)
                    QPrint("❌Load file Failed: \(error)")
                    let err = SFError.init()
                    err.errType = .LoadFileFailed
                    err.errInfo = "Load File Failed"
                    completionHandler(error: err)
                    return
                }
            }
            try? FileManager.default.removeItem(at: unzipDirectory)
            isLoadingFiles = false
            self.pushDialPlate(devIdentifier: devIdentifier, type: type, files: fileArray, maxFileSliceLength: maxFileSliceLength, withByteAlign: withByteAlign)
        }catch{
            QPrint("Unzip Failed: \(error)")
            let err = SFError.init()
            err.errType = .UnzipFailed
            err.errInfo = "Unzip Failed"
            completionHandler(error: err)
        }
    }
    
    /// 推送表盘文件
    /// - Parameters:
    ///   - devIdentifier: 目标设备的identifier字符串。通过CBPeripheral.identifier.uuidString获取
    ///   - type: 文件类型。0-表盘，1-多语言，2-背景图，3-自定义，4-音乐,5-JS,8-4g模块。其它类型查阅文档。
    ///   - files: 所推送的文件序列。
    ///   - maxFileSliceLength: 文件切片长度，默认1024字节。数值越大速度越快，但可能造成设备无法响应。该值应视具体设备而定。
    ///   - withByteAlign: 是否对文件进行CRC和字节对齐处理，需要依据具体的设备支持情况来决定该参数的取值。默认false。PS：当type为3时，总是会进行CRC和对齐操作，与该参数取值无关。当type=8 时，该参数无效，不会添加CRC和对齐
    @objc public func pushDialPlate(devIdentifier:String,type:UInt16, files:[SFFile], maxFileSliceLength:Int=1024, withByteAlign:Bool = false){
        
        if isBusy {
            QPrint("⚠️SFDialManager正忙")
            return
        }
        
        if maxFileSliceLength < 1{
            let error = SFError.init()
            error.errType = .InvalidValue
            error.errInfo = "maxFileSliceLength参数过小:\(maxFileSliceLength)"
            self.completionHandler(error: error)
            return
        }
        
        var handledFiles = files
        var interWithByteAlign = withByteAlign;
        if(type == 8){
            interWithByteAlign = false;
        }
        if type == 3 || interWithByteAlign{
            // 自定义文件或对齐标记为true时需要对文件进行4字节对齐以及添加CRC32/MPEG2校验
            handledFiles.removeAll()
            
            var paddedByte:UInt8 = 0x00// 文件对齐时使用的字节
            if type == 5 {
                // JS表盘，需要使用0x20对齐
                QPrint("文件类型为'5'(JS表盘)，使用0x20对齐")
                paddedByte = 0x20
            }
            for f in files{
                var srcData = f.file
                let modCount = srcData.count % 4
                if modCount != 0{
                    let appendData = Data.init(repeating: paddedByte, count: 4-modCount)
                    srcData.append(appendData)
                }
                
                var verifyValue = VerifyUtils.CRC32_MPEG2(src: srcData, offset: 0, length: srcData.count)
                let verifyData = NSData.init(bytes: &verifyValue, length: 4)
                srcData.append(Data.init(referencing: verifyData))
                handledFiles.append(SFFile.init(fileName: f.fileName, file: srcData))
            }
        }
        
        var gifFiles = Array<SFFile>.init()
        var restFiles = Array<SFFile>.init()
        for f in handledFiles{
            if f.fileName.lowercased().hasSuffix(".gif"){
                gifFiles.append(f)
            }else{
                restFiles.append(f)
            }
        }
        
        gifFiles = gifFiles.sorted(by: { pre, last in
            return pre.file.count > last.file.count
        })
        restFiles = restFiles.sorted(by: { pre, last in
            return pre.file.count > last.file.count
        })
        
        handledFiles = restFiles + gifFiles
        
        pushInfo = SFPushInfos.init(identifier: devIdentifier, type: type, files: handledFiles, maxFileSliceLength: maxFileSliceLength)
        totalBytes = 0
        completedBytes = 0
        for file in handledFiles {
            totalBytes += file.file.count
        }
        QPrint("[Original Arguments]: targetIdentifier=\(pushInfo!.targetIdentifier)")
        QPrint("[Original Arguments]: type=\(pushInfo!.type)")
        QPrint("[Original Arguments]: maxFileSliceLength=\(pushInfo!.maxFileSliceLength)")
        for file in pushInfo!.files{
            QPrint("[Original Arguments]: \(file.briefDes())")
        }

        
        let connectedPerArray = shell.retrievePairedPeripherals()
        var target:CBPeripheral?
        for per in connectedPerArray {
            if per.identifier.uuidString == self.pushInfo?.targetIdentifier {
                target = per
                break
            }
        }
        if let per = target {
            QPrint("✅找到目标外设，准备建立连接")
            searchTimer?.invalidate()
            searchTimer = nil
            shell.connect(peripheral: per, withShakehands: true)
        }else{
            // 尝试通过搜索的方式获取目标外设
            searchTimer = Timer.init(timeInterval: 10.0, target: self, selector: #selector(searchTimeoutHandler(timer:)), userInfo: nil, repeats: false)
            RunLoop.main.add(searchTimer!, forMode: .default)
            shell.startScan(withServicesFilter: false)
        }
    }
    @objc private func searchTimeoutHandler(timer:Timer) {
        // 没有搜索到找到目标外设
        if self.searchTimer == nil {
            QPrint("⚠️忽略searchTimer的回调")
            return
        }
        self.shell.stopScan()
        
        // 再尝试从连接列表中获取目标外设
        let connPerArray = self.shell.retrievePairedPeripherals()
        var targetPer:CBPeripheral?
        for per in connPerArray{
            if per.identifier.uuidString == self.pushInfo?.targetIdentifier {
                targetPer = per
                break
            }
        }
        guard let peripheral = targetPer else{
            
            let error = SFError.init()
            error.errType = .Timeout
            error.errInfo = "未找到目标外设:\(self.pushInfo?.targetIdentifier ?? "")"
            self.clearWorks()
            DispatchQueue.main.async {
                self.delegate?.dialPlateManager(manager: self, complete: error)
            }
            return
        }
        
        self.searchTimer?.invalidate()
        self.searchTimer = nil
        QPrint("✅找到目标外设(2)，准备建立连接")
        self.shell.connect(peripheral: peripheral, withShakehands: true)
    }
    
    
    /// 终止任务。
    @objc public func stop(){
        if !isBusy{
            shell.cancelConnection()
            return
        }
        if shell.isShakedHands {
            let terminateTask = SFDialPlateTermiateTask.init(reason: 10)
            shell.resume(task: terminateTask)
        }
       
        let error = SFError.init()
        error.errType = .Canceled
        error.errInfo = "推送任务被取消"
        completionHandler(error: error)
        shell.cancelConnection()
    }
    
    
    
    func dialPlateShell(shell: SFDialPlateShell, didDiscover peripheral: CBPeripheral) {
        
        if let timer = searchTimer, timer.isValid == true{
            // 处于搜索状态
            guard let info = pushInfo else{
                QPrint("⚠️没有推送任务，停止搜索")
                shell.stopScan()
                return
            }
            
            if peripheral.identifier.uuidString.uppercased() == info.targetIdentifier.uppercased(){
                // 找到目标外设
                shell.stopScan()
                searchTimer?.invalidate()
                searchTimer = nil
                QPrint("✅找到目标外设，准备建立连接")
                shell.connect(peripheral: peripheral, withShakehands: true)
            }
            
        }else{
            QPrint("⚠️未处于搜索状态，停止搜索")
            shell.stopScan()
        }
    }
    
    func dialPlateShell(shell: SFDialPlateShell, didUpdateState state: DPBleCoreManagerState) {
        QPrint("蓝牙状态改变:\(state)(\(state.rawValue))")
        
        DispatchQueue.main.async {
            self.delegate?.dialPlateManager(manager: self, didUpdateBLEState: state)
        }
    }
    
    func dialPlateShell(shell: SFDialPlateShell, failedToConnect peripheral: CBPeripheral, error: SFError) {
        if pushInfo == nil {
            QPrint("⚠️当前没有任务，忽略本次断开连接事件")
            return
        }
        QPrint("❌连接外设失败:\(error.errType)(\(error.errType.rawValue),\(error.errInfo))")
        clearWorks()
        DispatchQueue.main.async {
            self.delegate?.dialPlateManager(manager: self, complete: error)
        }
    }
    
    func dialPlateShell(shell: SFDialPlateShell, successToConnect peripheral: CBPeripheral, handShaked: Bool) {
        
        guard let info = pushInfo else{
            QPrint("⚠️当前没有任务，但收到BLE连接连接成功的回调，尝试断开连接")
            shell.cancelConnection()
            clearWorks()
            return
        }
        
        if info.targetIdentifier.uppercased() != peripheral.identifier.uuidString.uppercased(){
            QPrint("⚠️非目标设备('\(peripheral.identifier.uuidString)')建立了连接，准备断开")
            shell.cancelConnection()
            return
        }
        
        // 开始表盘推送流程
        // 总体开始
        pushStepEntireStart()
        
    }
    
    func dialPlateShell(shell: SFDialPlateShell, recieved devRsp: SFResponseBaseModel) {
        QPrint("⚠️收到设备主动发来的消息:cmd=\(devRsp.cmd.rawValue), data=\(devRsp.data.debugDescription)")
        if devRsp.cmd == .Lose_Check {
            let d = NSData.init(data: devRsp.data)
            
            if d.length < 6 {
                QPrint("⚠️设备主动上报的LoseCheck消息payload长度小于6字节，忽略")
            }
            var result:UInt16 = 0
            d.getBytes(&result, range: NSRange.init(location: 0, length: 2))
            
            if result == 8 {
                // 设备发来的abort指令，需要终止升级流程
                let error = SFError.init()
                error.errType = .DeviceAbort
                error.errInfo = "Device Send Abort Signal"
                self.completionHandler(error: error)
                return
            }
            
            if result == 7 || result == 2 {
                
                // 判断当前状态是否符合约定
                if !isSendingFile && !isLoseChecking {
                    QPrint("⚠️不处于SendingFile或LoseChecking状态呢，忽略本次LoseCheck")
                    return
                }
                
                var expectedOrderNumber:UInt32 = 0 // 从1计数
                d.getBytes(&expectedOrderNumber, range: NSRange.init(location: 2, length: 4))
                if expectedOrderNumber == 0 {
                    QPrint("⚠️设备主动上报的LoseCheck消息expectedOrderNumber为0，忽略")
                    return
                }
                
                // 已完成数量
                let completedCount = expectedOrderNumber - 1
                let currentFile = self.pushInfo!.files[self.currentFileIndex]
                if currentFile.fileSlice.count <= completedCount {
                    QPrint("⚠️异常的completedCount=\(completedCount), 当前文件: index=\(self.currentFileIndex), name=\(currentFile.fileName), sliceCount=\(currentFile.fileSlice.count)。忽略")
                    return
                }
                QPrint("ℹ️当前文件: index=\(self.currentFileIndex), name=\(currentFile.fileName), sliceCount=\(currentFile.fileSlice.count)")
                
                // 修改状态
                self.isLoseChecking = true
                self.isSendingFile = false
                
                // 暂停发送
                self.shell.clearAllTasks()
                
                if result == 2 {
                    // Serial Transport Receive Error
                    self.loseCheckReceiveErrorCount += 1
                    if self.loseCheckReceiveErrorCount >= 3 {
                        // 超过阈值，终止流程
                        let error = SFError.init()
                        error.errType = .FileSliceTooLarge
                        error.errInfo = "数据包过长，尝试减小启动推送时的maxFileSliceLength参数值"
                        self.completionHandler(error: error)
                        return
                    }
                }
                
//                self.delayRestartTimer?.invalidate()
//                self.delayRestartTimer = nil
                
                // 回复设备
                let loseCheckRspTask = SFDialPlateLoseCheckRspTask.init(result: 0)
                self.shell.resume(task: loseCheckRspTask)
                
                QPrint("⚠️调整包序号为'\(completedCount)'，1秒后重发。。。")
//                let timer = Timer.init(timeInterval: 1.0, target: self, selector: #selector(delayRestartHandler(timer:)), userInfo: completedCount, repeats: false)
//                self.delayRestartTimer = timer
//                RunLoop.main.add(timer, forMode: .default)
                QBleCore.sharedInstance.bleQueue.asyncAfter(deadline: .now() + 1) {
                    self .delayRestartHandler(completedCount: completedCount)
                }
            }else{
                // 其它Result
                QPrint("⚠️未知的LoseCheck Result:\(result)")
            }
        }
    }
    
    @objc private func delayRestartHandler(completedCount:UInt32) {
        QPrint("⚠️delayRestartHandler \(completedCount)")
//        let completedCount = timer.userInfo as! UInt32
        
//        self.delayRestartTimer?.invalidate()
//        self.delayRestartTimer = nil
        
        if !self.isLoseChecking {
            // 已经不在发送状态
            QPrint("⚠️已不在loseChecking状态，忽略针对LoseCheck的重发")
            return
        }
        if(self.pushInfo == nil){
            QPrint("⚠️pushInfo is nil，忽略针对LoseCheck的重发")
            return;
        }
        self.isLoseChecking = false
        self.isSendingFile = true
        let fileIndex = self.currentFileIndex
        
        self.pushStepSendFile(fileIndex: fileIndex, sliceIndex: Int(completedCount))
    }
    
    
    private func pushStepEntireStart(){
        var allFileLength = 0
        for f in pushInfo!.files{
            allFileLength += f.file.count
        }
        QPrint("推送总体开始: totalFileLength=\(allFileLength), fileList=\(pushInfo!.briefDes())")

        let entireStartTask =  SFDialPlateEntireStartTask.init(type: pushInfo!.type, phoneType: 1, allFileLength: UInt32(allFileLength)) {[weak self] task, error, result, maxDataLen, blockInfos in
            guard let s = self else{
                return
            }
            
            if !s.isBusy{
                QPrint("⚠️没有推送任务，忽略EntireStart回调")
                return
            }
            
            if let err = error {
                QPrint("总体开始失败,\(err.description)")
                s.completionHandler(error: err)
                return
            }
            
            QPrint("✅收到总体开始的响应:result=\(result),maxDataLen=\(maxDataLen), blockInfos=\(blockInfos?.briefDes() ?? "nil")")
            
            if result != 0{
                let err = s.errorWithResult(result: result)
                QPrint("❌总体开始失败,\(err.errInfo)")
                s.completionHandler(error: err)
                return
            }
            
            if maxDataLen == 0{
                QPrint("❌总体开始失败, 异常的maxDataLen: \(maxDataLen)")
                let err = SFError.init()
                err.errType = .InvalidValue
                err.errInfo = "设备返回异常的文件长度:\(maxDataLen)"
                s.completionHandler(error: err)
                return
            }
            var needTotalBlock:Int = 0
            if let info = blockInfos {
                s.deviceVersion = info.version
                let blockLength = info.blockLength
                let blockLeft = info.blockLeft
                if blockLength == 0 {
                    QPrint("❌总体开始失败,异常的blockLength=\(blockLength)")
                    let err = SFError.init()
                    err.errType = .InvalidValue
                    err.errInfo = "设备上传异常的blockLength=\(blockLength)"
                    s.completionHandler(error: err)
                    return
                }
                // 计算设备的剩余空间
               
                for f in s.pushInfo!.files {
                    let block = s.calculateFileBlock(blockLength: Int(blockLength), fileLength: f.file.count)
                    needTotalBlock += block
                }
//                if needTotalBlock > blockLeft {
//                    QPrint("❌总体开始失败, 设备剩余空间不足:needTotalBlock=\(needTotalBlock), leftBlock=\(blockLeft)")
//                    let err = SFError.init()
//                    err.errType = .InsufficientDeviceSpace
//                    err.errInfo = "设备剩余空间不足"
//                    let terminateTask = SFDialPlateTermiateTask.init(reason: 9)
//                    s.shell.resume(task: terminateTask)
//                    s.completionHandler(error: err)
//                    return
//                }
                
            }else{
                // 说明是老版本设备
                // 将版本号视作0
                s.deviceVersion = 0
            }
                        
            if s.pushInfo!.files.count == 0{
                QPrint("⚠️总体开始警告, 文件列表长度为0")
                s.completionHandler(error: nil)
                return
            }
            
//            var realMaxFileSliceLength = s.pushInfo!.maxFileSliceLength
//            if maxDataLen < s.pushInfo!.maxFileSliceLength{
//                QPrint("⚠️总体开始，重新分割文件: \(s.pushInfo!.maxFileSliceLength) ===> \(maxDataLen)")
//                realMaxFileSliceLength = maxDataLen
//            }
//            for f in s.pushInfo!.files{
//                f.reSliceFile(maxDataLen: realMaxFileSliceLength)
//            }
//            s.delegate?.dialPlateManager(manager: s, progress: s.formattedProgress(totalBytes: s.totalBytes, completedBytes: s.completedBytes))
//            s.pushStepFileStart(fileIndex: 0)
            QPrint("deviceVersion =\(String(describing: s.deviceVersion))")
            if(s.deviceVersion! < 1){
                s.readyToPushStepFileStart(maxDataLen: maxDataLen)
            }else{
                s.pushFileSpaceRequest(maxDataLen: maxDataLen, needTotalBlock:needTotalBlock)
            }
        }
        shell.resume(task: entireStartTask)
    }
    
    private func pushFileSpaceRequest(maxDataLen:Int,needTotalBlock:Int){
        QPrint("发送文件系统占用信息 pushFileSpaceRequest maxDataLen=\(maxDataLen),needTotalBlock=\(needTotalBlock)")
        let fileSpaceTask = SFDialPlateFileSpaceTask.init(wfBlock: UInt32(needTotalBlock)) { [weak self]task, error, result in
            guard let s = self else{
                return
            }
            
            if !s.isBusy{
                QPrint("⚠️没有推送任务，忽略FileSpace回调")
                return
            }
            
            if let err = error {
                QPrint("发送文件系统占用失败,\(err.description)")
                s.completionHandler(error: err)
                return
            }
            
           
            if result != 0{
                let err = s.errorWithResult(result: Int(result))
                QPrint("❌发送文件系统占用失败,\(err.errInfo)")
                s.completionHandler(error: err)
                return
            }
            s.readyToPushStepFileStart(maxDataLen: maxDataLen)
        }
        shell.resume(task: fileSpaceTask)
    }
    
    private func readyToPushStepFileStart(maxDataLen:Int){
        QPrint("readyToPushStepFileStart maxDataLen=\(maxDataLen)")
        let s = self
        var realMaxFileSliceLength = s.pushInfo!.maxFileSliceLength
        if maxDataLen < s.pushInfo!.maxFileSliceLength{
            QPrint("⚠️总体开始，重新分割文件: \(s.pushInfo!.maxFileSliceLength) ===> \(maxDataLen)")
            realMaxFileSliceLength = maxDataLen
        }
        QPrint("✅realMaxFileSliceLength=\(realMaxFileSliceLength)")
        for f in s.pushInfo!.files{
            f.reSliceFile(maxDataLen: realMaxFileSliceLength)
        }
        DispatchQueue.main.async {
            s.delegate?.dialPlateManager(manager: s, progress: s.formattedProgress(totalBytes: s.totalBytes, completedBytes: s.completedBytes))
        }
        
        s.pushStepFileStart(fileIndex: 0)
    }
    
    private func pushStepFileStart(fileIndex:Int){
        self.currentFileIndex = fileIndex
        
        let file = pushInfo!.files[fileIndex]
        
        QPrint("单文件开始: fileIndex=\(fileIndex), fileName=\(file.fileName), fileLength=\(file.file.count)")

                
        guard let fileNameData = file.fileName.data(using: .utf8) else{
            let err = SFError.init()
            err.errType = .EncodeError
            err.errInfo = "'\(file.fileName)'进行utf-8编码失败"
            self.completionHandler(error: err)
            return
        }
        let tsk = SFDialPlateFileStartTask.init(fileLen: UInt32(file.file.count), fileNameData: fileNameData) {[weak self] task, error, result in
            guard let s = self else{
                return
            }
            
            if !s.isBusy{
                QPrint("⚠️没有推送任务，忽略FileStart回调")
                return
            }
            
            if let err = error {
                QPrint("单文件开始失败, \(err.description)")
                s.completionHandler(error: err)
                return
            }
            if result != 0 {
                let err = s.errorWithResult(result: Int(result))
                QPrint("单文件开始失败, \(err.errInfo)")
                s.completionHandler(error: err)
                return
            }
            QPrint("单文件开始成功，开始发送文件数据...")
            s.pushStepSendFile(fileIndex: fileIndex, sliceIndex: 0)
        }
        shell.resume(task: tsk)
    }
    
    private func pushStepSendFile(fileIndex:Int, sliceIndex:Int){
        self.isSendingFile = true
        QPrint("发送文件数据: fileIndex=\(fileIndex), sliceIndex=\(sliceIndex)", notify: false)
        let file = self.pushInfo!.files[fileIndex]
        let fileSlice = file.fileSlice[sliceIndex]
        let sendIndex = sliceIndex+1 // 发送时的index信息从1计数
        let sendTask = SFDialPlateSendFileTask.init(index: UInt32(sendIndex), fileData: fileSlice) {[weak self] task, error, result, continueIndex in
            guard let s = self else{
                return
            }
            
            if !s.isBusy{
                QPrint("⚠️没有推送任务，忽略SendFile回调")
                return
            }
            
            
            let currentFileInfoLog = "{ fileIndex=\(fileIndex), fileName=\(file.fileName), fileLength=\(file.file.count) fileSliceCount=\(file.fileSlice.count),currentSliceIndex=\(sliceIndex) }"
            
            if let err = error{
                if err.errType == .Timeout{
                    // 尝试3次重新发送
                    if s.fileReSendCount < MaxFileReSendCount{
                        s.fileReSendCount += 1
                        QPrint("⚠️文件发送超时，尝试第'\(s.fileReSendCount)'重发:fileIndex=\(fileIndex), fileName=\(file.fileName), sliceIndex=\(sliceIndex), totalSliceCount=\(file.fileSlice.count)")
                        s.pushStepSendFile(fileIndex: fileIndex, sliceIndex: sliceIndex)
                        return
                    }else{
                        QPrint("❌❌❌文件重发连续超时失败达'\(s.fileReSendCount)'次")
                    }
                }
                QPrint("发送slice失败, \(err.description)。Sending Status: \(currentFileInfoLog)")
                s.completionHandler(error: err)
                return
            }
            
            // 清除重发次数记录
            s.fileReSendCount = 0
            
            if result != 0{
                if result == 4{
                    //
                    if continueIndex < 1{
                        let err = SFError.init()
                        err.errType = .InvalidValue
                        err.errInfo = "异常的continueIndex: \(continueIndex)"
                        QPrint("发送slice失败, \(err.errInfo)。Sending Status: \(currentFileInfoLog)")
                        s.completionHandler(error: err)
                        return
                    }
                    
                    let continueSliceIndex = continueIndex - 1
                    if continueSliceIndex > file.fileSlice.count - 1{
                        let err = SFError.init()
                        err.errType = .OutOfRange
                        err.errInfo = "continueIndex越界: continueIndex=\(continueIndex), totalSliceCount=\(file.fileSlice.count)"
                        QPrint("发送slice失败, \(err.errInfo)。Sending Status: \(currentFileInfoLog)")
                        s.completionHandler(error: err)
                        return
                    }
                    QPrint("⚠️根据设备返回的索引重新发送:continueIndex=\(continueIndex), sliceIndex=\(continueSliceIndex)")
                    s.pushStepSendFile(fileIndex: fileIndex, sliceIndex: continueSliceIndex)
                    return
                }
                
                let err = s.errorWithResult(result: result)
                QPrint("发送slice失败, \(err.errInfo)。Sending Status: \(currentFileInfoLog)")
                s.completionHandler(error: err)
                return
            }
            s.completedBytes += task.fileData.count
            DispatchQueue.main.async {
                s.delegate?.dialPlateManager(manager: s, progress: s.formattedProgress(totalBytes: s.totalBytes, completedBytes: s.completedBytes))
            }
            if sliceIndex < file.fileSlice.count-1{
                // 继续发送该file的其它slice
                s.pushStepSendFile(fileIndex: fileIndex, sliceIndex: sliceIndex+1)
            }else{
                // 发送fileEnd指令
                self?.isSendingFile = false
                QPrint("✅单文件发送完毕：\(currentFileInfoLog)")
                s.pushStepFileEnd(fileIndex: fileIndex)
            }
        }
        shell.resume(task: sendTask)
    }
    
    
    private func pushStepFileEnd(fileIndex:Int){
        
        QPrint("准备发送单文件结束指令: fileIndex=\(fileIndex)")

        let endTask = SFDialPlateFileEndTask.init {[weak self] task, error, result in
            
            guard let s = self else{
                return
            }
            
            if !s.isBusy{
                QPrint("⚠️没有推送任务，忽略FileEnd回调")
                return
            }
            
            if let err = error {
                s.completionHandler(error: err)
                return
            }
            
            if result != 0{
                let err = s.errorWithResult(result: Int(result))
                s.completionHandler(error: err)
                return
            }
            
            if fileIndex < s.pushInfo!.files.count - 1{
                // 还有其它文件
                s.pushStepFileStart(fileIndex: fileIndex + 1)
            }else{
                // 已经成功发送完最后一个文件，总体结束
                s.pushStepEntireEnd()
            }
            
        }
        shell.resume(task: endTask)
    }
    
    
    private func pushStepEntireEnd(){
        
        QPrint("发送总体结束指令")

        let entireEndTask = SFDialPlateEntireEndTask.init {[weak self] task, error, result in
            guard let s = self else{
                return
            }
            
            if !s.isBusy{
                QPrint("⚠️没有推送任务，忽略EntireEnd回调")
                return
            }
            
            if let err = error{
                QPrint("总体结束失败, \(err.errInfo)")
                s.completionHandler(error: err)
                return
            }
            
            if result != 0{
                let err = s.errorWithResult(result: Int(result))
                QPrint("总体结束失败, \(err.errInfo)")
                s.completionHandler(error: err)
                return
            }
            QPrint("✅✅✅表盘推送成功✅✅✅")
            s.completionHandler(error: nil)
        }
        shell.resume(task: entireEndTask)
    }
    
    
    private func formattedProgress(totalBytes:Int, completedBytes:Int) -> Int{
        if totalBytes == 0{
            QPrint("⚠️totalBytes为0，进度为0")
            return 0
        }
        let p = completedBytes*100/totalBytes
        return p
    }
    
    
    
    
    private func calculateFileBlock(blockLength:Int, fileLength:Int) -> Int {
        let count = fileLength/blockLength + (fileLength%blockLength > 0 ? 1:0)
        return count
    }
    
    
    private func clearWorks(){
        self.shell.clearAllTasks()
        self.currentFileIndex = 0
        self.isSendingFile = false
        self.isLoseChecking = false
        self.loseCheckReceiveErrorCount = 0
//        self.delayRestartTimer?.invalidate()
//        self.delayRestartTimer = nil
        isLoadingFiles = false
        self.searchTimer?.invalidate()
        self.searchTimer = nil
        self.totalBytes = 0
        self.completedBytes = 0
        self.fileReSendCount = 0
        self.deviceVersion = nil
        
        pushInfo = nil
    }
    
    
    private func completionHandler(error:SFError?){
        if self.searchTimer != nil{
            // 正在处于搜索状态
            self.shell.stopScan()
            self.searchTimer?.invalidate()
        }
        self.clearWorks()
        DispatchQueue.main.async {
            self.delegate?.dialPlateManager(manager: self, complete: error)
        }
       
        //表盘改为连续传输，任务结束不断开连接，stop()时机断开
//        shell.cancelConnection()
    }
    
    
    private func errorWithResult(result:Int) -> SFError{
        let err = SFError.init()
        err.errType = .ErrorCode
        err.errInfo = "设备返回错误码:\(result)"
        err.devErrorCode = NSNumber.init(integerLiteral: result)
        return err
    }
}
