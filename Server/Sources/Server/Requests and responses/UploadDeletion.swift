//
//  DeleteFile.swift
//  Server
//
//  Created by Christopher Prince on 2/18/17.
//
//

import Foundation
import Gloss

#if SERVER
import Kitura
#endif

// This places a deletion request in the Upload table on the server. A DoneUploads request is subsequently required to actually perform the deletion in cloud storage.
// An upload deletion can be repeated for the same file: This doesn't cause an error and doesn't duplicate rows in the Upload table.

class UploadDeletionRequest : NSObject, RequestMessage, Filenaming {
    // The use of the Filenaming protocol here is to support the DEBUG `actualDeletion` parameter.
    
    // MARK: Properties for use in request message.
    
    static let fileUUIDKey = "fileUUID"
    var fileUUID:String!
    
    // This must indicate the current version of the file in the FileIndex.
    static let fileVersionKey = "fileVersion"
    var fileVersion:FileVersionInt!
    
    // Overall version for files for the specific user; assigned by the server.
    static let masterVersionKey = "masterVersion"
    var masterVersion:MasterVersionInt!

#if DEBUG
    // Enable the client to actually delete files-- for testing purposes. The UploadDeletionRequest will not queue the request, but instead deletes from both the FileIndex and from cloud storage.
    static let actualDeletionKey = "actualDeletion"
    var actualDeletion:Int32? // Should be 0 or non-0; I haven't been able to get Bool to work with Gloss
#endif
    
    func nonNilKeys() -> [String] {
        return [UploadDeletionRequest.fileUUIDKey, UploadDeletionRequest.fileVersionKey, UploadDeletionRequest.masterVersionKey]
    }
    
    func allKeys() -> [String] {
        var keys = [String]()
        keys += self.nonNilKeys()
#if DEBUG
        keys += [UploadDeletionRequest.actualDeletionKey]
#endif
        return keys
    }
    
    required init?(json: JSON) {
        super.init()
        
        self.fileUUID = UploadDeletionRequest.fileUUIDKey <~~ json
        self.masterVersion = UploadDeletionRequest.masterVersionKey <~~ json
        self.fileVersion = UploadDeletionRequest.fileVersionKey <~~ json
        
#if DEBUG
        self.actualDeletion = UploadDeletionRequest.actualDeletionKey <~~ json
#endif
        
        if !self.propertiesHaveValues(propertyNames: self.nonNilKeys()) {
            return nil
        }
        
        guard let _ = NSUUID(uuidString: self.fileUUID) else {
            return nil
        }
    }
    
#if SERVER
    required convenience init?(request: RouterRequest) {
        self.init(json: request.queryParameters)
    }
#endif
    
    func toJSON() -> JSON? {
        var param:[JSON?] = []
        
        param += [
            UploadDeletionRequest.fileUUIDKey ~~> self.fileUUID,
            UploadDeletionRequest.masterVersionKey ~~> self.masterVersion,
            UploadDeletionRequest.fileVersionKey ~~> self.fileVersion
        ]
        
#if DEBUG
        param += [
            UploadDeletionRequest.actualDeletionKey ~~> self.actualDeletion
        ]
#endif
        
        return jsonify(param)
    }
}

class UploadDeletionResponse : ResponseMessage {
    public var responseType: ResponseType {
        return .json
    }
    
    // If the master version for the user on the server has been incremented, this key will be present in the response-- with the new value of the master version. The upload deletion was not attempted in this case.
    static let masterVersionUpdateKey = "masterVersionUpdate"
    var masterVersionUpdate:Int64?
    
    required init?(json: JSON) {
        self.masterVersionUpdate = UploadDeletionResponse.masterVersionUpdateKey <~~ json
    }
    
    convenience init?() {
        self.init(json:[:])
    }
    
    // MARK: - Serialization
    func toJSON() -> JSON? {
        return jsonify([
            UploadDeletionResponse.masterVersionUpdateKey ~~> self.masterVersionUpdate
        ])
    }
}
