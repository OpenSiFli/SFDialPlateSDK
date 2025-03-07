//
//  SFDialPlateFileSpaceTask.swift
//  SFDialPlateSDK
//
//  Created by Sean on 2023/12/1.
//

import UIKit

class SFDialPlateFileSpaceTask: SFDialPlateBaseTask {
    let wfBlock:UInt32
    let completion:ResultCompletion?
    init(wfBlock: UInt32,completion:ResultCompletion?) {
        self.completion = completion;
        self.wfBlock = wfBlock
        let totalData = NSMutableData.init()
        
        
//        var fLen:UInt16 = 4
        var block = wfBlock;
//        totalData.append(&fLen, length: 2)
        totalData.append(&block, length: 4)
        super.init(cmd: .FileSpace_Request, reservedData: Data.init(referencing: totalData))
        
        self.baseCompletion = {[weak self] (error, rspModel) in
            
            guard let s = self else{
                return
            }
            
            if let err = error {
                s.completion?(s, err, 0)
                return
            }
            
            let d = NSData.init(data: rspModel!.data)
            if d.count < 2 {
                let err = SFError.init()
                err.errType = .InvalidValue
                err.errInfo = "文件系统占用回复数据长度不足"
                s.completion?(s, err, 0)
                return
            }
            
            var result:UInt16 = 0
            
            d.getBytes(&result, range: NSRange.init(location: 0, length: 2))
            
            s.completion?(s, nil , result)
            
        }
    }
}
