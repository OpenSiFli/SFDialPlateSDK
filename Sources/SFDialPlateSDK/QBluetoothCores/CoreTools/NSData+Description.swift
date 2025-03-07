import Foundation

extension NSData{
    
    open override var debugDescription: String{
        var content = "<"
        for i in 0..<self.length {
            var v:UInt8 = 0
            self.getBytes(&v, range: NSMakeRange(i, 1))
            if i>0 && i%4 == 0 {
                content.append(" ")
            }
            content.append(String.init(format: "%.2x", v))
        }
        content.append(">")
        return content
    }
    
}
