import Foundation

class SFDialPlateTermiateTask: SFDialPlateBaseTask {
    let reason:UInt8
    init(reason:UInt8) {
        self.reason = reason
        var r = reason
        let d = Data.init(bytes: &r, count: 1)
        super.init(cmd: .Terminate, reservedData: d)
    }
}
