import Foundation


class SFPushInfos{
    let targetIdentifier:String
    let type:UInt16
    let files:[SFFile]
    let maxFileSliceLength:Int
    
    init(identifier:String, type:UInt16, files:[SFFile], maxFileSliceLength:Int){
        self.targetIdentifier = identifier
        self.type = type
        self.files = files
        self.maxFileSliceLength = maxFileSliceLength
    }
    
    func briefDes() -> String{
        
        var fileContent = ""
        for f in files{
            if fileContent.count != 0{
                fileContent.append(",\n")
            }
            fileContent.append(f.briefDes())
        }
        fileContent = "[\(fileContent)]"
        
        let content = "targetIdentifier=\(self.targetIdentifier), type=\(self.type), maxFileSliceLength=\(self.maxFileSliceLength), files=\(fileContent)"
        
        return content
    }
}
