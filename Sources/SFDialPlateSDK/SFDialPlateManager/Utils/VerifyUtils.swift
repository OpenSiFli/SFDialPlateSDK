//
//  CRC32MPEG2.swift
//  SFDialPlateSDK
//
//  Created by 秦晟哲 on 2022/5/17.
//

import Foundation

class VerifyUtils {
    static func CRC32_MPEG2(src:Data, offset:Int, length:Int) -> UInt32{
        var crc:UInt32 = 0xffffffff
        let len = length+offset
        for j in offset..<len{
            crc ^= UInt32(src[j]) << 24
            for _ in 0..<8{
                if (crc & 0x80000000) != 0{
                    crc = (crc<<1) ^ 0x04C11DB7
                }else{
                    crc <<= 1
                }
            }
        }
        return crc
    }
}
