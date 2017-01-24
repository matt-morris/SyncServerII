//
//  FileIndexRepository.swift
//  Server
//
//  Created by Christopher Prince on 1/21/17.
//
//

// Meta data for files currently in cloud storage.

import Foundation
import PerfectLib

class FileIndex : NSObject, Model {
    var fileIndexId: Int64!
    var fileUUID: String!
    var userId: Int64!
    var mimeType: String!
    var appMetaData: String!
    
    let deletedKey = "deleted"
    var deleted:Bool!
    
    var fileVersion: Int32!
    
    var fileSizeBytes: Int64!
    
    func typeConvertersToModel(propertyName:String) -> ((_ propertyValue:Any) -> Any?)? {
        switch propertyName {
            case deletedKey:
                return {(x:Any) -> Any? in
                    return (x as! Int8) == 1
                }
            
            default:
                return nil
        }
    }
}

class FileIndexRepository : Repository {
    static var tableName:String {
        return "FileIndex"
    }
    
    static func create() -> Database.TableCreationResult {        
        let createColumns =
            "(fileIndexId BIGINT NOT NULL AUTO_INCREMENT, " +
            
            // Together, these two form a unique key. The deviceUUID is needed because two devices using the same userId (i.e., the same owning user credentials) could be uploading the same file at the same time.
        
            // permanent reference to file (assigned by app)
            "fileUUID VARCHAR(\(Database.uuidLength)) NOT NULL, " +
        
            // reference into User table
            "userId BIGINT NOT NULL, " +
                
            // MIME type of the file
            "mimeType VARCHAR(\(Database.maxMimeTypeLength)) NOT NULL, " +

            // App-specific meta data
            "appMetaData TEXT, " +

            // true if file has been deleted, false if not.
            "deleted BOOL NOT NULL, " +
            
            "fileVersion INT NOT NULL, " +

            "fileSizeBytes BIGINT NOT NULL, " +

            "UNIQUE (fileUUID, userId), " +
            "UNIQUE (fileIndexId))"
        
        return Database.session.createTableIfNeeded(tableName: "\(tableName)", columnCreateQuery: createColumns)
    }
    
    private static func columnNames(appMetaDataFieldName:String = "appMetaData,") -> String {
        return "fileUUID, userId, mimeType, \(appMetaDataFieldName) deleted, fileVersion, fileSizeBytes"
    }
    
    // uploadId in the model is ignored and the automatically generated uploadId is returned if the add is successful.
    static func add(fileIndex:FileIndex) -> Int64? {
        if fileIndex.fileUUID == nil || fileIndex.userId == nil || fileIndex.mimeType == nil || fileIndex.deleted == nil || fileIndex.fileVersion == nil || fileIndex.fileSizeBytes == nil {
            Log.error(message: "One of the model values was nil!")
            return nil
        }
    
        var appMetaDataFieldValue = ""
        var columns = columnNames(appMetaDataFieldName: "")
        
        if fileIndex.appMetaData != nil {
            // TODO: Seems like we could use an encoding here to deal with sql injection issues.
            appMetaDataFieldValue = ", '\(fileIndex.appMetaData!)'"
            
            columns = columnNames()
        }
        
        let deletedValue = fileIndex.deleted == true ? 1 : 0
        
        let query = "INSERT INTO \(tableName) (\(columns)) VALUES('\(fileIndex.fileUUID!)', \(fileIndex.userId!), '\(fileIndex.mimeType!)' \(appMetaDataFieldValue), \(deletedValue), \(fileIndex.fileVersion!), \(fileIndex.fileSizeBytes!));"
        
        if Database.session.connection.query(statement: query) {
            return Database.session.connection.lastInsertId()
        }
        else {
            let error = Database.session.error
            Log.error(message: "Could not insert row into \(tableName): \(error)")
            return nil
        }
    }
    
    enum LookupKey : CustomStringConvertible {
        case fileIndexId(Int64)
        case primaryKeys(userId:String, fileUUID:String)
        
        var description : String {
            switch self {
            case .fileIndexId(let fileIndexId):
                return "fileIndexId(\(fileIndexId))"
            case .primaryKeys(let userId, let fileUUID):
                return "userId(\(userId)); fileUUID(\(fileUUID))"
            }
        }
    }
    
    static func lookupConstraint(key:LookupKey) -> String {
        switch key {
        case .fileIndexId(let fileIndexId):
            return "fileIndexId = '\(fileIndexId)'"
        case .primaryKeys(let userId, let fileUUID):
            return "userId = \(userId) and fileUUID = '\(fileUUID)'"
        }
    }
    
    // Returns nil on failure, and on success returns the number of uploads transferred.
    static func transferUploads(userId: Int64, deviceUUID:String) -> Int32? {
        // The ordering of fields in the INSERT must match that in selectForTransferToUpload.
        let query = "INSERT INTO \(tableName) (\(columnNames())) " +
        UploadRepository.selectForTransferToUpload(userId: userId, deviceUUID: deviceUUID)
        
        if Database.session.connection.query(statement: query) {
            return Int32(Database.session.connection.numberAffectedRows())
        }
        else {
            let error = Database.session.error
            Log.error(message: "Could not transferUploads: \(error)")
            return nil
        }
    }
}