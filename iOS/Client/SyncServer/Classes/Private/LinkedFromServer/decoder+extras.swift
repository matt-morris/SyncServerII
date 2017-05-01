//
//  Decoder+Extras.swift
//  Server
//
//  Created by Christopher Prince on 4/26/17.
//
//

import Foundation
import Gloss

// This extension is here because (a) the Kitura RouterRequest queryParameters property returns integers as strings (i.e., quoted), and (b) Gloss doesn't interpret strings as integers by default.

extension Decoder {
    // Attempt to convert a String to an Int of type T
    private static func decodeStringAsInt<T: Integer>(json: JSON, toInt:(String) -> T?, keyPath: String, keyPathDelimiter: String) -> T? {
    
        if let string = json.valueForKeyPath(keyPath: keyPath, withDelimiter: keyPathDelimiter) as? String {
            return toInt(string)
        }
        
        return nil
    }
    
    static func decode(int32ForKey key: String, keyPathDelimiter: String = GlossKeyPathDelimiter) -> (JSON) -> Int32? {
        return {
            json in
            
            if let number = json.valueForKeyPath(keyPath: key, withDelimiter: keyPathDelimiter) as? NSNumber {
                return number.int32Value
            }
            
            return decodeStringAsInt(json: json, toInt:{ Int32($0) }, keyPath: key, keyPathDelimiter: keyPathDelimiter)
        }
    }
    
    static func decode(int64ForKey key: String, keyPathDelimiter: String = GlossKeyPathDelimiter) -> (JSON) -> Int64? {
        return {
            json in
            
            if let number = json.valueForKeyPath(keyPath: key, withDelimiter: keyPathDelimiter) as? NSNumber {
                return number.int64Value
            }
            
            return decodeStringAsInt(json: json, toInt:{ Int64($0) }, keyPath: key, keyPathDelimiter: keyPathDelimiter)
        }
    }
}