import Foundation


class SFDialPlateFileStartTask:SFDialPlateBaseTask{
    
    let fileLen:UInt32
    let fileNameData:Data
    
    let completion:ResultCompletion?
    
    init(fileLen:UInt32, fileNameData:Data, completion:ResultCompletion?){
        
        self.completion = completion
        
        let totalData = NSMutableData.init()
        
        self.fileLen = fileLen
        var fLen = fileLen
        totalData.append(&fLen, length: 4)
        
        var nameLen = UInt16(fileNameData.count)
        totalData.append(&nameLen, length: 2)
        
        self.fileNameData = fileNameData
        totalData.append(fileNameData)
        
        super.init(cmd: .FileStart_Request, reservedData: Data.init(referencing: totalData))
        
        self.baseCompletion = {[weak self] (error, rspModel) in
            
            guard let s = self else{
                return
            }
            
            if let err = error {
                s.completion?(s, err, 0)
                return
            }
            
            let d = NSData.init(data: rspModel!.data)
            
            var result:UInt16 = 0
            
            d.getBytes(&result, range: NSRange.init(location: 0, length: 2))
            
            s.completion?(s, nil , result)
            
        }
        
    }

    
}
