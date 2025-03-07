import Foundation


@objc public class SFFile:NSObject {
    
    /// 文件名。包含文件后缀。
    @objc public let fileName:String
    
    /// 文件内容。
    @objc public let file:Data
    
    private(set) var fileSlice:[Data] = []
    
    /// 构造函数
    /// - Parameters:
    ///   - fileName: 文件名。包含文件后缀
    ///   - file: 文件内容。
    @objc public init(fileName:String, file:Data) {
        self.fileName = fileName
        self.file = file
        super.init()
    }
    
    func reSliceFile(maxDataLen:Int){
        let maxSliceLen = maxDataLen
        self.fileSlice = QDataTools.SplitData(data: self.file, upperlimit: maxSliceLen)
    }
    
    func briefDes() -> String{
        let content = "<fileName=\(fileName), length=\(file.count)>"
        return content
    }
}
