
import UIKit

//public class QLogModel: NSObject {
//    @objc public var modulName:String = ""
//    @objc public var time:TimeInterval = 0
//    @objc public var fileName:String = ""
//    @objc public var funcName:String = ""
//    @objc public var lineNum:Int = 0
//    @objc public var message:Any?
//
//
//    /// time格式化后的字符串
//    ///
//    /// - Returns: HH:mm:ss+SSS毫秒
//    @objc public func formattedTime() -> String{
//        let formatter = DateFormatter.init()
//        formatter.dateFormat = "HH:mm:ss+SSS"
//        let date = Date.init(timeIntervalSince1970: time)
//        let timeStr = formatter.string(from: date) + "毫秒"
//        return timeStr
//    }
//}
//
//@objc public protocol QBleLogManagerDelegate:NSObjectProtocol{
//    func bleLogManager(manager:QBleLogManager,logModel:QLogModel)
//}
@objc public enum DialPlateLogLevel:NSInteger {
    case info = 0 // 信息
    case warn = 1 // 警告
    case debug = 2 // 调试信息
    case error = 3 // 错误
}

@objc public protocol SFLogManagerDelegate: NSObjectProtocol {
    
    func sfLogManager(manager:SFLogManager, onLog log:SFCommonLogModel!,logLevel level:DialPlateLogLevel)
}

public class SFLogManager: NSObject {
    @objc public static let share = SFLogManager.init()
    
    /// SDK内部日志开关。当关闭时，控制台不再打印内容，但QBleLogManagerDelegate的回调不受影响。
    @objc public var openLog:Bool = true
    
    /// 日志委托外部处理
    @objc weak public var delegate:SFLogManagerDelegate?
    
    private override init() {
        super.init()
    }

}
