# SFDialPlateSDK
SFDialPlateSDK
SiFli Solution 1.1.0 Dial Transmission Component

## 1.zip file

```
    /// 推送表盘文件
    /// - Parameters:
    ///   - devIdentifier: 目标设备的identifier字符串。通过CBPeripheral.identifier.uuidString获取
    ///   - type: 文件类型。0-表盘，1-多语言，2-背景图，3-自定义，4-音乐,5-JS,8-4g模块,9-sfwatchface。其它类型查阅文档。
    ///   - zipPath: zip格式的升级文件位于本地的url
    ///   - maxFileSliceLength: 文件切片长度，默认1024字节。数值越大速度越快，但可能造成设备无法响应。该值应视具体设备而定。
    ///   - withByteAlign: 是否对文件进行CRC和字节对齐处理，需要依据具体的设备支持情况来决定该参数的取值。默认false。PS：当type为3时，总是会进行CRC和对齐操作，与该参数取值无关。当type=8 时，该参数无效，不会添加CRC和对齐
    @objc public func pushDialPlate(devIdentifier:String, type:UInt16, zipPath:URL, maxFileSliceLength:Int=1024, withByteAlign:Bool = false)

```

## 2.file collection

```
  /// 推送表盘文件
    /// - Parameters:
    ///   - devIdentifier: 目标设备的identifier字符串。通过CBPeripheral.identifier.uuidString获取
    ///   - type: 文件类型。0-表盘，1-多语言，2-背景图，3-自定义，4-音乐,5-JS,8-4g模块。其它类型查阅文档。
    ///   - files: 所推送的文件序列。
    ///   - maxFileSliceLength: 文件切片长度，默认1024字节。数值越大速度越快，但可能造成设备无法响应。该值应视具体设备而定。
    ///   - withByteAlign: 是否对文件进行CRC和字节对齐处理，需要依据具体的设备支持情况来决定该参数的取值。默认false。PS：当type为3时，总是会进行CRC和对齐操作，与该参数取值无关。当type=8 时，该参数无效，不会添加CRC和对齐
    @objc public func pushDialPlate(devIdentifier:String,type:UInt16, files:[SFFile], maxFileSliceLength:Int=1024, withByteAlign:Bool = false)
```