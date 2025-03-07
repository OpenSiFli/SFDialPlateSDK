import Foundation

class SFDialPlateBlockInfos{
    let version:UInt16
    let blockLength:UInt16
    let blockLeft:UInt32
    init(version:UInt16, blockLength: UInt16, blockLeft: UInt32) {
        self.version = version
        self.blockLength = blockLength
        self.blockLeft = blockLeft
    }
    
    func briefDes() -> String {
        return "{version=\(version), blockLength=\(blockLength), blockLeft=\(blockLeft)}"
    }
}

typealias EntireStartCompletion = (_ task:SFDialPlateBaseTask ,_ error:SFError?, _ result:Int, _ maxDataLen:Int, _ blockInfos:SFDialPlateBlockInfos?) -> Void


class SFDialPlateEntireStartTask:SFDialPlateBaseTask{
    
    let type:UInt16
    let phoneType:UInt8
    let allFileLength:UInt32
    
    let completion:EntireStartCompletion?
    
    init(type:UInt16, phoneType:UInt8, allFileLength:UInt32, completion:EntireStartCompletion?){
        
        let reservedData = NSMutableData.init()
        
        self.completion = completion
        
        self.type = type
        var t = type
        reservedData.append(&t, length: 2)
        
        self.phoneType = phoneType
        var pt = phoneType
        reservedData.append(&pt, length: 1)
        
        self.allFileLength = allFileLength
        var allFL = allFileLength
        reservedData.append(&allFL, length: 4)
        
        super.init(cmd: .EntireStart_Request, reservedData: Data.init(referencing: reservedData))
        
        self.baseCompletion = {[weak self] (error, rspModel) in
            guard let s = self else{
                return
            }
            if let err = error {
                s.completion?(s,err, 0, 0, nil)
                return
            }
            
            let data = NSData.init(data: rspModel!.data)
            if data.count < 4{
                let err = SFError.init()
                err.errType = .InvalidDataStruct
                err.errInfo = "data段长度('\(data.count)')小于4"
                s.completion?(s, err, 0, 0, nil)
                return
            }
            
            var result:UInt16 = 0
            data.getBytes(&result, range: NSRange.init(location: 0, length: 2))
            
            var maxLen:UInt16 = 0
            data.getBytes(&maxLen, range: NSRange.init(location: 2, length: 2))
            
            var blockInfos:SFDialPlateBlockInfos?
            
            if result == 0 {
                // 只有result为0，才可能会有后面的结构
                if data.length > 4 {
                    // 新版本
                    var version:UInt16 = 0
                    data.getBytes(&version, range: NSRange.init(location: 4, length: 2))
                    
                    if version > 0 {
                        // 新版本
                        if data.length < 12 {
                            QPrint("❌设备版本'\(version)', 但data长度小于12")
                            let err = SFError.init()
                            err.errType = .InvalidDataStruct
                            err.errInfo = "data段长度('\(data.count)')小于12"
                            s.completion?(s,err,0,0,nil)
                            return
                        }
                        var blockLength:UInt16 = 0
                        data.getBytes(&blockLength, range: NSRange.init(location: 6, length: 2))
                        
                        var blockLeft:UInt32 = 0
                        data.getBytes(&blockLeft, range: NSRange.init(location: 8, length: 4))
                        
                        blockInfos = SFDialPlateBlockInfos.init(version: version, blockLength: blockLength, blockLeft: blockLeft)
                    }else{
                        QPrint("⚠️设备上传的version为0，不做继续进行block解析")
                    }
                    
                }else{
                    // 老版本，没有后续结构
                    QPrint("⚠️旧版本设备，没有version和block信息")
                }
            }
            
            s.completion?(s, nil, Int(result), Int(maxLen), blockInfos)
        }
    }
}
