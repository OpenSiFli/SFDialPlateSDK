import Foundation

class PathUtils: NSObject {
    static func DocumentPath()->String{
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        return paths[0]
    }
    
    
    
    static func TempUnzipRootFolder()->String{
        let document = NSString.init(string: DocumentPath())
        let rootFolder = document.appendingPathComponent("TempUnzipFiles")
        
        let manager = FileManager.default
        var isDir = ObjCBool.init(false)
        let existed = manager.fileExists(atPath: rootFolder, isDirectory: &isDir)
        if existed == false || isDir.boolValue == false {
            // 创建文件夹
            try? manager.createDirectory(atPath: rootFolder, withIntermediateDirectories: true, attributes: nil)
        }
        return rootFolder
    }
    
    
    static func TempUnzipFolder(folderName:String) -> String{
        let rootFolder = NSString.init(string: TempUnzipRootFolder())
        let folder = rootFolder.appendingPathComponent(folderName)
        
        let manager = FileManager.default
        var isDir = ObjCBool.init(false)
        let existed = manager.fileExists(atPath: folder, isDirectory: &isDir)
        if existed == false || isDir.boolValue == false {
            // 创建文件夹
            try? manager.createDirectory(atPath: folder, withIntermediateDirectories: true, attributes: nil)
        }
        return folder
    }
    
    static func RelativeFilePaths(rootPath:URL) -> [String]?{
        
        let fileManager = FileManager.default
        var filePathArray = Array<String>.init()
        let contents = fileManager.enumerator(atPath: rootPath.path)!
        while let content = contents.nextObject(){
            guard let s =  content as? String else{
                QPrint("unzip failed: could not convert '\(content)' to String")
                return nil
            }
            var isDir = ObjCBool.init(false)
            fileManager.fileExists(atPath: rootPath.appendingPathComponent(s).path, isDirectory: &isDir)
            if isDir.boolValue == false{
                filePathArray.append(s)
            }
        }
        return filePathArray
    }

}
