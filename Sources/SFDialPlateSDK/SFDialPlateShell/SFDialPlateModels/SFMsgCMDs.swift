import Foundation

enum SFDialPlateCMD:UInt16 {
    case EntireStart_Request = 0
    case EntireStart_Response = 1
    
    case FileStart_Request = 2
    case FileStart_Response = 3
    
    case SendFile_Request = 4
    case SendFile_Response = 5
    
    case FileEnd_Request = 6
    case FileEnd_Response = 7
    
    case EntireEnd_Request = 8
    case EntireEnd_Response = 9
    
    case Lose_Check = 10
    case Lose_Check_Response = 11
    
    case Terminate = 12
    
    case FileSpace_Request = 13
    case FileSpace_Response = 14
}


class SFCmdsTools: NSObject {
    static func IsPaired(requestCmd:SFDialPlateCMD,responseCmd:SFDialPlateCMD) -> Bool{
        let req = requestCmd
        let rsp = responseCmd
        if  req == .EntireStart_Request && rsp == .EntireStart_Response {
            return true
        }
        if req == .FileStart_Request && rsp == .FileStart_Response{
            return true
        }
        if req == .SendFile_Request && rsp == .SendFile_Response{
            return true
        }
        if req == .FileEnd_Request && rsp == .FileEnd_Response{
            return true
        }
        if req == .EntireEnd_Request && rsp == .EntireEnd_Response{
            return true
        }
        if req == .FileSpace_Request && rsp == .FileSpace_Response{
            return true
        }
        
        return false
        
    }
}
