import Foundation

typealias DialPlateSendCompletion = (_ task:SFDialPlateSendFileTask ,_ error:SFError?, _ result:Int, _ continueIndex:Int) -> Void

class SFDialPlateSendFileTask: SFDialPlateBaseTask{
    
    let completion:DialPlateSendCompletion?
    let index:UInt32
    let fileData:Data
    init(index:UInt32, fileData:Data, completion:DialPlateSendCompletion?){
        
        self.index = index
        self.fileData = fileData
        self.completion = completion
        
        let totalData = NSMutableData.init()
        
        var idx:UInt32 = index
        totalData.append(&idx, length: 4)
        
        totalData.append(fileData)
        
        super.init(cmd: .SendFile_Request, reservedData: Data.init(referencing: totalData))
        
        self.baseCompletion = {[weak self] (error, rspModel) in
            
            guard let s = self else{
                return
            }
            
            if let err = error {
                s.completion?(s, err, -1, -1)
                return
            }
            
            if rspModel!.data.count < 6{
                let err = SFError.init()
                err.errType = .InvalidDataStruct
                err.errInfo = "data部分小于6字节"
                s.completion?(s, err, -1, -1)
                return
            }
            
            let d = NSData.init(data: rspModel!.data)
            
            var result:UInt16 = 0
            d.getBytes(&result, range: NSRange.init(location: 0, length: 2))
            
            var continueIndex:UInt16 = 0
            d.getBytes(&continueIndex, range: NSRange.init(location: 2, length: 4))
            
            s.completion?(s, nil , Int(result), Int(continueIndex))
            
        }
        
        
    }
}
