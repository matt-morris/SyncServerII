//
//  FileController.swift
//  Server
//
//  Created by Christopher Prince on 1/15/17.
//
//

import Foundation
import PerfectLib
import Credentials
import CredentialsGoogle

class FileController : ControllerProtocol {
    // Don't do this setup in init so that database initalizations don't have to be done per endpoint call.
    class func setup(db:Database) -> Bool {
        if case .failure(_) = UploadRepository(db).create() {
            return false
        }
        
        if case .failure(_) = FileIndexRepository(db).create() {
            return false
        }
        
        if case .failure(_) = LockRepository(db).create() {
            return false
        }
        
        return true
    }
    
    init() {
    }
    
    enum GetMasterVersionError : Error {
    case error(String)
    case noObjectFound
    }
    
    // Synchronous callback.
    func getMasterVersion(params:RequestProcessingParameters, completion:(Error?, MasterVersionInt?)->()) {
        let key = MasterVersionRepository.LookupKey.userId(params.currentSignedInUser!.userId)
        let result = params.repos.masterVersion.lookup(key: key, modelInit: MasterVersion.init)
        
        switch result {
        case .error(let error):
            completion(GetMasterVersionError.error(error), nil)
            
        case .found(let model):
            let masterVersionObj = model as! MasterVersion
            completion(nil, masterVersionObj.masterVersion)
            
        case .noObjectFound:
            let errorMessage = "Master version record not found for userId: \(params.currentSignedInUser!.userId)"
            Log.error(message: errorMessage)
            completion(GetMasterVersionError.noObjectFound, nil)
        }
    }
            
    func fileIndex(params:RequestProcessingParameters) {
        guard params.request is FileIndexRequest else {
            Log.error(message: "Did not receive FileIndexRequest")
            params.completion(nil)
            return
        }
        
        getMasterVersion(params: params) { (error, masterVersion) in
            if error != nil {
                params.completion(nil)
                return
            }
            
            let fileIndexResult = params.repos.fileIndex.fileIndex(forUserId: params.currentSignedInUser!.userId)

            switch fileIndexResult {
            case .fileIndex(let fileIndex):
                Log.info(message: "Number of entries in FileIndex: \(fileIndex.count)")
                let response = FileIndexResponse()!
                response.fileIndex = fileIndex
                response.masterVersion = masterVersion
                params.completion(response)
                
            case .error(let error):
                Log.error(message: "Error: \(error)")
                params.completion(nil)
                return
            }
        }
    }
        
    func getUploads(params:RequestProcessingParameters) {
        guard params.request is GetUploadsRequest else {
            Log.error(message: "Did not receive GetUploadsRequest")
            params.completion(nil)
            return
        }
        
        let uploadsResult = params.repos.upload.uploadedFiles(forUserId: params.currentSignedInUser!.userId, deviceUUID: params.deviceUUID!)

        switch uploadsResult {
        case .uploads(let uploads):
            let response = GetUploadsResponse()!
            response.uploads = uploads
            params.completion(response)
            
        case .error(let error):
            Log.error(message: "Error: \(error)")
            params.completion(nil)
            return
        }
    }
}
