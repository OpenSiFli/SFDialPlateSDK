import Foundation


class SFDialPlateEntireEndTask:SFDialPlateBaseTask{
    
    
    let completion:ResultCompletion?
    
    init(completion:ResultCompletion?){
        self.completion = completion
        super.init(cmd: .EntireEnd_Request, reservedData: Data.init())
        
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
