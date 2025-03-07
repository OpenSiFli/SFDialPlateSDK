import UIKit

typealias ResultCompletion = (_ task:SFDialPlateBaseTask, _ error:SFError?, _ result:UInt16) -> Void

typealias BaseTaskCompletion = (_ error:SFError?,_ rsp:SFResponseBaseModel?)->Void

protocol BaseTaskDelegate:NSObjectProtocol {
    func baseTaskTimeout(task:SFDialPlateBaseTask)
}

class SFDialPlateBaseTask: NSObject {
    var timeout = 60.0
    let cmd:SFDialPlateCMD
    let reservedData:Data
    var baseCompletion:BaseTaskCompletion?
    weak var delegate:BaseTaskDelegate?
    private var timer:Timer?
    init(cmd:SFDialPlateCMD, reservedData:Data) {
        self.cmd = cmd
        self.reservedData = reservedData
        super.init()
    }
    
//    func toPacks(mtu:Int) -> [Data] {
//        var cmdValue = cmd.rawValue
//        let cmdData = Data.init(bytes: &cmdValue, count: 2)
//
//        var length:UInt16 = UInt16(self.reservedData.count)
//        let lenData = Data.init(bytes: &length, count: 2)
//
//        var totalData = Data.init()
//        totalData.append(cmdData)
//        totalData.append(lenData)
//        totalData.append(self.reservedData)
//
//        let maxLength = mtu - 3 - 2
//
//        return QDataTools.SplitData(data: totalData, upperlimit: maxLength)
//
//    }
    
    func toMsgData() -> Data{
        
        var cmdValue = cmd.rawValue
        let cmdData = Data.init(bytes: &cmdValue, count: 2)

        var length:UInt16 = UInt16(self.reservedData.count)
        let lenData = Data.init(bytes: &length, count: 2)
        
        var totalData = Data.init()
        totalData.append(cmdData)
        totalData.append(lenData)
        totalData.append(self.reservedData)
        
        return totalData
    }
    
    func startTimer() {
        timer?.invalidate()
        timer = Timer.init(timeInterval: timeout, target: self, selector: #selector(timeoutHandler(timer:)), userInfo: nil, repeats: false)
        RunLoop.main.add(timer!, forMode: .default)
    }
    @objc private func timeoutHandler(timer:Timer) {
        self.delegate?.baseTaskTimeout(task: self)
    }
    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
