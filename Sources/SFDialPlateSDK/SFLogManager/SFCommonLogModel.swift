import Foundation

@objc public class SFCommonLogModel:NSObject {
    
    /// 时间戳，毫秒
    @objc public let timestamp:Int
    
    
    /// 日志内容
    @objc public let message:String
    
    @objc public init(timestamp: Int, message: String) {
        self.timestamp = timestamp
        self.message = message
        super.init()
    }
    
}
