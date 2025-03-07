
import Foundation

let dateFormatter = DateFormatter.init()

let notificationCenter = NotificationCenter.default


func QPrint<T>(_ message:T,file:String = #file,funcName:String = #function,lineNum:Int = #line,notify:Bool = true){
    let msgDes = NSString.init(string: "\(message)")
    let fileDes = NSString.init(string: "\(file)")
    let funcDes = NSString.init(string: "\(funcName)")
    let lineDes = NSString.init(string: "\(lineNum)")
    
    
    
    if SFLogManager.share.openLog {
        NSLog("[SFDial \(Const_SDKVersion)] [%@ %@][%@]\n%@\n", fileDes.lastPathComponent,funcDes,lineDes,msgDes)
//        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss SSS"
//        let nowString = dateFormatter.string(from: Date.init())
//        print("\(nowString) [SFDialPlateManager] [\(fileDes.lastPathComponent) \(funcDes)][\(lineDes)]\n\(msgDes)\n")
    }
    if notify {
        let now = Date.init()
        let ms = Int(now.timeIntervalSince1970 * 1000)
        let logContent = "[SFDialN \(Const_SDKVersion)][\(fileDes.lastPathComponent) \(funcDes)][\(lineDes)]: \(msgDes)"
        let model = SFCommonLogModel.init(timestamp: ms, message: logContent)
        NotificationCenter.default.post(name: Notification_CommonLog, object: model)
        if(SFLogManager.share.delegate != nil){
            SFLogManager.share.delegate?.sfLogManager(manager: SFLogManager.share, onLog:model, logLevel: .info)
        }
    }
    
//    if enableToDelegate {
//        let now = Date.init()
//
//        let model = QLogModel.init()
//        model.modulName = "QBleOTASDK"
//        model.time = now.timeIntervalSince1970
//        model.fileName = (file as NSString).lastPathComponent
//        model.funcName = funcName
//        model.lineNum = lineNum
//        model.message = message
//
//        QBleLogManager.share.delegate?.bleLogManager(manager: QBleLogManager.share, logModel: model)
//    }

}
