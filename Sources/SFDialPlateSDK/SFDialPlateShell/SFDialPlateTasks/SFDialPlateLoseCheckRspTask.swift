import UIKit

class SFDialPlateLoseCheckRspTask: SFDialPlateBaseTask {
    
    let result:UInt16
    init(result:UInt16) {
        self.result = result
        var r = result
        let d = Data.init(bytes: &r, count: 2)
        super.init(cmd: .Lose_Check_Response, reservedData: d)
    }

}
