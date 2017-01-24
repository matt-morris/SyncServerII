//
//  Constants.swift
//  Server
//
//  Created by Christopher Prince on 12/26/16.
//
//

import Foundation
import SMServerLib

// Server-internal constants

protocol ConstantsDelegate {
func configFilePath(forConstants:Constants) -> String
}

class Constants {
    /* When adding this .json into your Xcode project make sure to
    a) add it into Copy Files in Build Phases, and 
    b) select Products Directory as a destination.
    For testing, I've had to put a build script in that does:
        cp Server.json /tmp
    */
    static let serverConfigFile = "Server.json"
    
    // TODO: Don't know what this should be
    static let serverConfigFilePathOnLinux = ""
    
    struct mySQL {
        var host:String = ""
        var user:String = ""
        var password:String = ""
        var database:String = ""
    }
    var db = mySQL()
    
    var googleClientId:String = ""
    var googleClientSecret:String = ""

    static var session = Constants()

    // If there is a delegate, then use this to get the config file path. This is purely a hack for testing-- because I've not been able to get access to the Server.config file otherwise.
    static var delegate:ConstantsDelegate?
    
    fileprivate init() {
        var config:ConfigLoader
        
        if Constants.delegate == nil {
#if os(macOS)
            config = try! ConfigLoader(fileNameInBundle: Constants.serverConfigFile, forConfigType: .jsonDictionary)
#else
            config = try! ConfigLoader(usingPath: Constants.serverConfigFilePathOnLinux, andFileName: Constants.serverConfigFile, forConfigType: .jsonDictionary)
#endif
        }
        else {
            let path = Constants.delegate!.configFilePath(forConstants: self)
            config = try! ConfigLoader(usingPath: path, andFileName: Constants.serverConfigFile, forConfigType: .jsonDictionary)
        }
        
        googleClientId = try! config.getString(varName: "GoogleServerClientId")
        googleClientSecret = try! config.getString(varName: "GoogleServerSecret")

        db.host = try! config.getString(varName: "mySQL.host")
        db.user = try! config.getString(varName: "mySQL.user")
        db.password = try! config.getString(varName: "mySQL.password")
        db.database = try! config.getString(varName: "mySQL.database")
    }
}