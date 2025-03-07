import Foundation

/// 错误类型定义
@objc public enum SFErrorType:NSInteger {
    case Unknown = 0
    case Timeout
    case NoConnection
    case Canceled
    case Disconnected
    case FailedToConnect
    ///响应数据无效
    case InvalidDataStruct
    ///收到设备错误码
    case ErrorCode
    ///转码失败
    case EncodeError
    ///响应数据不合法
    case InvalidValue
    ///收到数据超出预计范围
    case OutOfRange
    ///解压文件失败
    case UnzipFailed
    ///输入文件无效
    case InvalidFile
    ///加载文件失败
    case LoadFileFailed
    ///设备拒绝
    case DeviceAbort
    ///文件切片过大
    case FileSliceTooLarge
    ///设备剩余空间不足
    case InsufficientDeviceSpace
}

 class DevWatchFaceError{
    static let share = DevWatchFaceError.init()
    var errorDict = Dictionary<Int,String>.init()
    init(){
        errorDict[0] = "BLE_WATCHFACE_STATUS_OK"
        errorDict[1] = "BLE_WATCHFACE_STATUS_GENERAL_ERROR"
        errorDict[2] = "BLE_WATCHFACE_STATUS_RECEIVE_ERROR"
        errorDict[3] = "BLE_WATCHFACE_STATUS_LEN_ERROR"
        errorDict[4] = "BLE_WATCHFACE_STATUS_INDEX_ERROR"
        errorDict[5] = "BLE_WATCHFACE_STATUS_STATE_ERROR"
        
        errorDict[6] = "BLE_WATCHFACE_STATUS_DISCONNECT"
        errorDict[7] = "BLE_WATCHFACE_STATUS_DOWNLOAD_NOT_ONGOING"
        errorDict[8] = "BLE_WATCHFACE_STATUS_REMOTE_ABORT"
        errorDict[9] = "BLE_WATCHFACE_STATUS_REMOTE_FILE_SIZE_CHECK_ERROR"
        
        errorDict[20] = "BLE_WATCHFACE_STATUS_APP_ERROR"
        errorDict[21] = "BLE_WATCHFACE_STATUS_FILE_SIZE_ALIGNED_MISSING"
        errorDict[22] = "BLE_WATCHFACE_STATUS_FILE_PATH_ERROR"
        errorDict[23] = "BLE_WATCHFACE_STATUS_FILE_TYPE_ERROR"
        errorDict[24] = "BLE_WATCHFACE_STATUS_MEM_MALLOC_ERROR"
        errorDict[25] = "BLE_WATCHFACE_STATUS_FILE_OPEN_ERROR"
        
        errorDict[26] = "BLE_WATCHFACE_STATUS_FILE_INFO_ERROR"
        errorDict[27] = "BLE_WATCHFACE_STATUS_FILE_WRITE_ERROR"
        errorDict[28] = "BLE_WATCHFACE_STATUS_FILE_CLOSE_ERROR"
        errorDict[29] = "BLE_WATCHFACE_STATUS_FILE_EXTENSION_ERROR"
        errorDict[30] = "BLE_WATCHFACE_STATUS_MKDIR_ERROR"
        
        errorDict[31] = "BLE_WATCHFACE_STATUS_SWITCH_DIRECTORY_ERROR"
        errorDict[32] = "BLE_WATCHFACE_STATUS_BLE_PARAMETERS_NULL"
        errorDict[33] = "BLE_WATCHFACE_STATUS_MEM_NOT_CONTINUOUS"
        errorDict[34] = "BLE_WATCHFACE_STATUS_FILE_SIZE_ERROR"
        errorDict[35] = "BLE_WATCHFACE_STATUS_CRC_INIT_ERROR"
        
        errorDict[36] = "BLE_WATCHFACE_STATUS_CRC_CALCULATE_ERROR"
        errorDict[37] = "BLE_WATCHFACE_STATUS_SPACE_ERROR"
        errorDict[38] = "BLE_WATCHFACE_STATUS_TIMEOUT_ERROR"
        errorDict[39] = "BLE_WATCHFACE_STATUS_UI_INVALID"
        errorDict[40] = "BLE_WATCHFACE_STATUS_BLE_DISCONNECT"
        
        errorDict[41] = "BLE_WATCHFACE_STATUS_USER_ABORT"
        errorDict[42] = "BLE_WATCHFACE_STATUS_RECV_DATA_TIMEOUT"
    }
     
     func hasCode(code:Int)->Bool{
         return errorDict.keys.contains(code);
     }
     
     func valueOfKey(code:Int) -> String{
         if hasCode(code: code) {
             return errorDict[code]!;
         }else{
             return "未知的设备错误码:\(code)"
         }
     }
}

@objc public class SFError:NSObject{
    
    /// 错误类型
    @objc public var errType:SFErrorType = .Unknown
    
    /// 错误信息
    @objc public var errInfo = ""
    
    /// 当errType为ErrorCode(7)时，可从该属性获取到设备返回的错误码值，Int类型
    /// 已知设备端定义如下，可能随升级变更
    /// typedef enum
    ///    {
    ///        BLE_WATCHFACE_STATUS_OK =0 ,
    ///        BLE_WATCHFACE_STATUS_GENERAL_ERROR =1,
    ///        BLE_WATCHFACE_STATUS_RECEIVE_ERROR =2,
    ///        BLE_WATCHFACE_STATUS_LEN_ERROR=3,/
    ///        BLE_WATCHFACE_STATUS_INDEX_ERROR=4,
    ///        BLE_WATCHFACE_STATUS_STATE_ERROR=5,/
    ///        BLE_WATCHFACE_STATUS_DISCONNECT=6,
    ///        BLE_WATCHFACE_STATUS_DOWNLOAD_NOT_ONGOING=7,
    ///        BLE_WATCHFACE_STATUS_REMOTE_ABORT =8,
    ///        BLE_WATCHFACE_STATUS_REMOTE_FILE_SIZE_CHECK_ERROR=9
    ///
    ///        BLE_WATCHFACE_STATUS_APP_ERROR = 20,
    ///        BLE_WATCHFACE_STATUS_FILE_SIZE_ALIGNED_MISSING =21,
    ///        BLE_WATCHFACE_STATUS_FILE_PATH_ERROR=22,
    ///        BLE_WATCHFACE_STATUS_FILE_TYPE_ERROR=23,
    ///        BLE_WATCHFACE_STATUS_MEM_MALLOC_ERROR=24,
    ///        BLE_WATCHFACE_STATUS_FILE_OPEN_ERROR=25,
    ///        BLE_WATCHFACE_STATUS_FILE_INFO_ERROR=26,
    ///        BLE_WATCHFACE_STATUS_FILE_WRITE_ERROR=27,
    ///        BLE_WATCHFACE_STATUS_FILE_CLOSE_ERROR=28,
    ///        BLE_WATCHFACE_STATUS_FILE_EXTENSION_ERROR=29,
    ///        BLE_WATCHFACE_STATUS_MKDIR_ERROR=30,
    ///        BLE_WATCHFACE_STATUS_SWITCH_DIRECTORY_ERROR=31,
    ///        BLE_WATCHFACE_STATUS_BLE_PARAMETERS_NULL=32,
    ///        BLE_WATCHFACE_STATUS_MEM_NOT_CONTINUOUS=33,
    ///        BLE_WATCHFACE_STATUS_FILE_SIZE_ERROR=34,
    ///        BLE_WATCHFACE_STATUS_CRC_INIT_ERROR=35,
    ///        BLE_WATCHFACE_STATUS_CRC_CALCULATE_ERROR=36,
    ///        BLE_WATCHFACE_STATUS_SPACE_ERROR=37,
    ///        BLE_WATCHFACE_STATUS_TIMEOUT_ERROR=38,
    ///        BLE_WATCHFACE_STATUS_UI_INVALID=39,
    ///        BLE_WATCHFACE_STATUS_BLE_DISCONNECT = 40,
    ///        BLE_WATCHFACE_STATUS_USER_ABORT = 41,
    ///        BLE_WATCHFACE_STATUS_RECV_DATA_TIMEOUT = 42
    ///    } ble_watchface_status_id_t;
    @objc public var devErrorCode:NSNumber?
    
    /// 错误码
    @objc override public var description: String {
        return "errType=\(self.errType.rawValue),errInfo=\(self.errInfo)"
    }
    
    @objc override public init(){
        super.init()
    }
    
    @objc public func devErrorMsg() -> String{
        
        if let code = devErrorCode {
            let intCode = code.intValue
            return DevWatchFaceError.share.valueOfKey(code: intCode)
        }else{
            return ""
        }
    }
}
