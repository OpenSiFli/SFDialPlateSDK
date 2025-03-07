import Foundation

public class SFResponseBaseModel:NSObject{
    let cmd:SFDialPlateCMD
    let data:Data
    init(cmd:SFDialPlateCMD, data:Data){
        self.cmd = cmd
        self.data = data
        super.init()
    }
}


