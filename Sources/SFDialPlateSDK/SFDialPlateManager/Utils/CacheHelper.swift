//
//  CacheHelper.swift
//  SFDialPlateSDK
//
//  Created by Sean on 2025/11/25.
//

import Foundation
enum ZipLoadError: Error {
    case CreateCacheDirectoryFailed
}
class CacheHelper{
    /// 重新创建缓存目录（兼容 iOS 9.0+）
    /// - Parameter directory: 目录名称
    /// - Returns: 目录的URL地址
    static func reCreateCacheDirectory(directory: String)throws -> URL {
        let fileManager = FileManager.default
        let tempDirectory = getTemporaryDirectory()
        let cacheDirectoryURL = tempDirectory.appendingPathComponent(directory)
        
        // 检查目录是否存在
        if fileManager.fileExists(atPath: cacheDirectoryURL.path) {
            do {
                // 删除已存在的目录
                try fileManager.removeItem(at: cacheDirectoryURL)
                QPrint("已删除现有目录: \(cacheDirectoryURL.path)")
            } catch {
                QPrint("删除目录失败: \(error)")
                throw ZipLoadError.CreateCacheDirectoryFailed
            }
        }
        
        do {
            // 创建新目录
            try fileManager.createDirectory(at: cacheDirectoryURL,
                                            withIntermediateDirectories: true,
                                            attributes: nil)
            QPrint("成功创建目录: \(cacheDirectoryURL.path)")
            return cacheDirectoryURL
        } catch {
            QPrint("创建目录失败: \(error)")
            throw ZipLoadError.CreateCacheDirectoryFailed
        }
    }
    
    /// 获取临时目录URL，兼容 iOS 9.0+
    static func getTemporaryDirectory() -> URL {
        if #available(iOS 10.0, *) {
            // iOS 10.0+ 使用新的 API
            return FileManager.default.temporaryDirectory
        } else {
            // iOS 10.0 之前的实现
            let tempPath = NSTemporaryDirectory()
            return URL(fileURLWithPath: tempPath)
        }
    }
}

