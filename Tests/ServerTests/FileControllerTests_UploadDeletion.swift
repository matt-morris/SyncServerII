//
//  FileControllerTests_UploadDeletion.swift
//  Server
//
//  Created by Christopher Prince on 2/18/17.
//
//

import XCTest
@testable import Server
import LoggerAPI
import Foundation
import SyncServerShared

class FileControllerTests_UploadDeletion: ServerTestCase, LinuxTestable {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    // TODO: *1* To test these it would be best to have a debugging endpoint or other service where we can test to see if the file is present in cloud storage.
    
    // TODO: *1* Also useful would be a service that lets us directly delete a file from cloud storage-- to simulate errors in file deletion.

    func testThatUploadDeletionTransfersToUploads() {
        let deviceUUID = Foundation.UUID().uuidString
        guard let uploadResult1 = uploadTextFile(deviceUUID:deviceUUID), let sharingGroupId = uploadResult1.sharingGroupId else {
            XCTFail()
            return
        }
        
        self.sendDoneUploads(expectedNumberOfUploads: 1, deviceUUID:deviceUUID, sharingGroupId: sharingGroupId)
        
        let uploadDeletionRequest = UploadDeletionRequest(json: [
            UploadDeletionRequest.fileUUIDKey: uploadResult1.request.fileUUID,
            UploadDeletionRequest.fileVersionKey: uploadResult1.request.fileVersion,
            UploadDeletionRequest.masterVersionKey: uploadResult1.request.masterVersion + MasterVersionInt(1),
            ServerEndpoint.sharingGroupIdKey: sharingGroupId
        ])!
        
        uploadDeletion(uploadDeletionRequest: uploadDeletionRequest, deviceUUID: deviceUUID, addUser: false)

        let expectedDeletionState = [
            uploadResult1.request.fileUUID: true,
        ]
        
        self.getUploads(expectedFiles: [uploadResult1.request], deviceUUID:deviceUUID, matchOptionals: false, expectedDeletionState:expectedDeletionState, sharingGroupId:sharingGroupId)
        
        self.sendDoneUploads(expectedNumberOfUploads: 1, deviceUUID:deviceUUID, masterVersion: uploadResult1.request.masterVersion + MasterVersionInt(1), sharingGroupId: sharingGroupId)

        self.getUploads(expectedFiles: [], deviceUUID:deviceUUID, matchOptionals: false, sharingGroupId:sharingGroupId)
    }
    
    func testThatCombinedUploadDeletionAndFileUploadWork() {
        let deviceUUID = Foundation.UUID().uuidString
        guard let uploadResult1 = uploadTextFile(deviceUUID:deviceUUID), let sharingGroupId = uploadResult1.sharingGroupId else {
            XCTFail()
            return
        }
        
        self.sendDoneUploads(expectedNumberOfUploads: 1, deviceUUID:deviceUUID, sharingGroupId: sharingGroupId)
        
        let uploadDeletionRequest = UploadDeletionRequest(json: [
            UploadDeletionRequest.fileUUIDKey: uploadResult1.request.fileUUID,
            UploadDeletionRequest.fileVersionKey: uploadResult1.request.fileVersion,
            UploadDeletionRequest.masterVersionKey: uploadResult1.request.masterVersion + MasterVersionInt(1),
            ServerEndpoint.sharingGroupIdKey: sharingGroupId
        ])!
        
        uploadDeletion(uploadDeletionRequest: uploadDeletionRequest, deviceUUID: deviceUUID, addUser: false)
        
        let expectedDeletionState = [
            uploadResult1.request.fileUUID: true,
        ]
        
        self.getUploads(expectedFiles: [uploadResult1.request], deviceUUID:deviceUUID, matchOptionals: false, expectedDeletionState:expectedDeletionState, sharingGroupId:sharingGroupId)
        
        self.sendDoneUploads(expectedNumberOfUploads: 1, deviceUUID:deviceUUID, masterVersion: uploadResult1.request.masterVersion + MasterVersionInt(1), sharingGroupId: sharingGroupId)
        
        self.getUploads(expectedFiles: [], deviceUUID:deviceUUID, matchOptionals: false, sharingGroupId:sharingGroupId)
        
        let expectedSizes = [
            uploadResult1.request.fileUUID: uploadResult1.fileSize
        ]
        
        self.getFileIndex(expectedFiles: [uploadResult1.request], masterVersionExpected: uploadResult1.request.masterVersion + MasterVersionInt(2), expectedFileSizes: expectedSizes, sharingGroupId: sharingGroupId, expectedDeletionState:expectedDeletionState)
    }
    
    func testThatUploadDeletionTwiceOfSameFileWorks() {
        let deviceUUID = Foundation.UUID().uuidString
        guard let uploadResult1 = uploadTextFile(deviceUUID:deviceUUID), let sharingGroupId = uploadResult1.sharingGroupId else {
            XCTFail()
            return
        }
        
        self.sendDoneUploads(expectedNumberOfUploads: 1, deviceUUID:deviceUUID, sharingGroupId: sharingGroupId)
        
        let uploadDeletionRequest = UploadDeletionRequest(json: [
            UploadDeletionRequest.fileUUIDKey: uploadResult1.request.fileUUID,
            UploadDeletionRequest.fileVersionKey: uploadResult1.request.fileVersion,
            UploadDeletionRequest.masterVersionKey: uploadResult1.request.masterVersion + MasterVersionInt(1),
            ServerEndpoint.sharingGroupIdKey: sharingGroupId
        ])!
        
        uploadDeletion(uploadDeletionRequest: uploadDeletionRequest, deviceUUID: deviceUUID, addUser: false)

        uploadDeletion(uploadDeletionRequest: uploadDeletionRequest, deviceUUID: deviceUUID, addUser: false)

        let expectedDeletionState = [
            uploadResult1.request.fileUUID: true,
        ]
        
        self.getUploads(expectedFiles: [uploadResult1.request], deviceUUID:deviceUUID, matchOptionals: false, expectedDeletionState:expectedDeletionState, sharingGroupId:sharingGroupId)
    }
    
    func testThatUploadDeletionFollowedByDoneUploadsActuallyDeletes() {
        let deviceUUID = Foundation.UUID().uuidString
        
        // This file is going to be deleted.
        guard let uploadResult1 = uploadTextFile(deviceUUID:deviceUUID),
            let sharingGroupId = uploadResult1.sharingGroupId else {
            XCTFail()
            return
        }
        
        self.sendDoneUploads(expectedNumberOfUploads: 1, deviceUUID:deviceUUID, sharingGroupId: sharingGroupId)
        
        let uploadDeletionRequest = UploadDeletionRequest(json: [
            UploadDeletionRequest.fileUUIDKey: uploadResult1.request.fileUUID,
            UploadDeletionRequest.fileVersionKey: uploadResult1.request.fileVersion,
            UploadDeletionRequest.masterVersionKey: uploadResult1.request.masterVersion + MasterVersionInt(1),
            ServerEndpoint.sharingGroupIdKey: sharingGroupId
        ])!
        
        uploadDeletion(uploadDeletionRequest: uploadDeletionRequest, deviceUUID: deviceUUID, addUser: false)
        
        // This file will not be deleted.
        guard let uploadResult2 = uploadTextFile(deviceUUID:deviceUUID, addUser:.no(sharingGroupId: sharingGroupId), masterVersion: uploadResult1.request.masterVersion + MasterVersionInt(1)) else {
            XCTFail()
            return
        }

        let expectedDeletionState = [
            uploadResult1.request.fileUUID: true,
            uploadResult2.request.fileUUID: false
        ]
        
        self.getUploads(expectedFiles: [uploadResult1.request, uploadResult2.request], deviceUUID:deviceUUID, matchOptionals: false, expectedDeletionState:expectedDeletionState, sharingGroupId:sharingGroupId)

        self.sendDoneUploads(expectedNumberOfUploads: 2, deviceUUID:deviceUUID, masterVersion: uploadResult1.request.masterVersion + MasterVersionInt(1), sharingGroupId: sharingGroupId)
        
        self.getUploads(expectedFiles: [], deviceUUID:deviceUUID, matchOptionals: false, expectedDeletionState:expectedDeletionState, sharingGroupId:sharingGroupId)
        
        let expectedSizes = [
            uploadResult1.request.fileUUID: uploadResult1.fileSize,
            uploadResult2.request.fileUUID: uploadResult2.fileSize,
        ]

        self.getFileIndex(expectedFiles: [uploadResult1.request, uploadResult2.request], masterVersionExpected: uploadResult1.request.masterVersion + MasterVersionInt(2), expectedFileSizes: expectedSizes, sharingGroupId: sharingGroupId, expectedDeletionState:expectedDeletionState)
    }
    
    // TODO: *0* Test upload deletion with with 2 files

    func testThatDeletionOfDifferentVersionFails() {
        let deviceUUID = Foundation.UUID().uuidString
        
        guard let uploadResult1 = uploadTextFile(deviceUUID:deviceUUID),
            let sharingGroupId = uploadResult1.sharingGroupId else {
            XCTFail()
            return
        }
        
        self.sendDoneUploads(expectedNumberOfUploads: 1, deviceUUID:deviceUUID, sharingGroupId: sharingGroupId)
        
        let uploadDeletionRequest = UploadDeletionRequest(json: [
            UploadDeletionRequest.fileUUIDKey: uploadResult1.request.fileUUID,
            UploadDeletionRequest.fileVersionKey: uploadResult1.request.fileVersion + FileVersionInt(1),
            UploadDeletionRequest.masterVersionKey: uploadResult1.request.masterVersion + MasterVersionInt(1),
            ServerEndpoint.sharingGroupIdKey: sharingGroupId
        ])!
        
        uploadDeletion(uploadDeletionRequest: uploadDeletionRequest, deviceUUID: deviceUUID, addUser: false, expectError: true)
    }
    
    func testThatDeletionOfUnknownFileUUIDFails() {
        let deviceUUID = Foundation.UUID().uuidString
        
        guard let uploadResult = uploadTextFile(deviceUUID:deviceUUID),
            let sharingGroupId = uploadResult.sharingGroupId else {
            XCTFail()
            return
        }
        
        self.sendDoneUploads(expectedNumberOfUploads: 1, deviceUUID:deviceUUID, sharingGroupId: sharingGroupId)
        
        let uploadDeletionRequest = UploadDeletionRequest(json: [
            UploadDeletionRequest.fileUUIDKey: Foundation.UUID().uuidString,
            UploadDeletionRequest.fileVersionKey: uploadResult.request.fileVersion,
            UploadDeletionRequest.masterVersionKey: uploadResult.request.masterVersion + MasterVersionInt(1),
            ServerEndpoint.sharingGroupIdKey: sharingGroupId
        ])!
        
        uploadDeletion(uploadDeletionRequest: uploadDeletionRequest, deviceUUID: deviceUUID, addUser: false, expectError: true)
    }
    
    // TODO: *1* Make sure a deviceUUID from a different user cannot do an UploadDeletion for our file.
    
    func testThatDeletionFailsWhenMasterVersionDoesNotMatch() {
        let deviceUUID = Foundation.UUID().uuidString
        
        guard let uploadResult = uploadTextFile(deviceUUID:deviceUUID),
            let sharingGroupId = uploadResult.sharingGroupId else {
            XCTFail()
            return
        }
        
        self.sendDoneUploads(expectedNumberOfUploads: 1, deviceUUID:deviceUUID, sharingGroupId: sharingGroupId)
        
        let uploadDeletionRequest = UploadDeletionRequest(json: [
            UploadDeletionRequest.fileUUIDKey: uploadResult.request.fileUUID,
            UploadDeletionRequest.fileVersionKey: uploadResult.request.fileVersion,
            UploadDeletionRequest.masterVersionKey: MasterVersionInt(100),
            ServerEndpoint.sharingGroupIdKey: sharingGroupId
        ])!
        
        uploadDeletion(uploadDeletionRequest: uploadDeletionRequest, deviceUUID: deviceUUID, addUser: false, updatedMasterVersionExpected: 1)
    }
    
    func testThatDebugDeletionFromServerWorks() {
        let deviceUUID = Foundation.UUID().uuidString
        
        guard let uploadResult = uploadTextFile(deviceUUID:deviceUUID),
            let sharingGroupId = uploadResult.sharingGroupId else {
            XCTFail()
            return
        }
        
        self.sendDoneUploads(expectedNumberOfUploads: 1, deviceUUID:deviceUUID, sharingGroupId: sharingGroupId)
        
        let uploadDeletionRequest = UploadDeletionRequest(json: [
            UploadDeletionRequest.fileUUIDKey: uploadResult.request.fileUUID,
            UploadDeletionRequest.fileVersionKey: uploadResult.request.fileVersion,
            UploadDeletionRequest.masterVersionKey: uploadResult.request.masterVersion + MasterVersionInt(1),
            UploadDeletionRequest.actualDeletionKey: Int32(1),
            ServerEndpoint.sharingGroupIdKey: sharingGroupId
        ])!
        
        uploadDeletion(uploadDeletionRequest: uploadDeletionRequest, deviceUUID: deviceUUID, addUser: false)
        
        // Make sure deletion actually occurred!
        
        self.getFileIndex(expectedFiles: [], masterVersionExpected: uploadResult.request.masterVersion + MasterVersionInt(1), expectedFileSizes: [:], sharingGroupId: sharingGroupId, expectedDeletionState:[:])
        
        self.performServerTest { expectation, creds in
            let cloudFileName = uploadDeletionRequest.cloudFileName(deviceUUID: deviceUUID, mimeType: uploadResult.request.mimeType)
            
            let options = CloudStorageFileNameOptions(cloudFolderName: ServerTestCase.cloudFolderName, mimeType: uploadResult.request.mimeType)
            
            let cloudStorageCreds = creds as! CloudStorage
            cloudStorageCreds.lookupFile(cloudFileName:cloudFileName, options:options) { result in
                switch result {
                case .success(let found):
                    XCTAssert(!found)
                case .failure:
                    XCTFail()
                }
                
                expectation.fulfill()
            }
        }
    }
    
    // Until today, 3/31/17, I had a bug in the server where this didn't work. It would try to delete the file using a name given by the the deviceUUID of the deleting device, not the uploading device.
    func testThatUploadByOneDeviceAndDeletionByAnotherActuallyDeletes() {
        let deviceUUID1 = Foundation.UUID().uuidString
        
        // This file is going to be deleted.
        guard let uploadResult = uploadTextFile(deviceUUID:deviceUUID1),
            let sharingGroupId = uploadResult.sharingGroupId else {
            XCTFail()
            return
        }
        
        self.sendDoneUploads(expectedNumberOfUploads: 1, deviceUUID:deviceUUID1, sharingGroupId: sharingGroupId)
        
        let uploadDeletionRequest = UploadDeletionRequest(json: [
            UploadDeletionRequest.fileUUIDKey: uploadResult.request.fileUUID,
            UploadDeletionRequest.fileVersionKey: uploadResult.request.fileVersion,
            UploadDeletionRequest.masterVersionKey: uploadResult.request.masterVersion + MasterVersionInt(1),
            ServerEndpoint.sharingGroupIdKey: sharingGroupId
        ])!
        
        let deviceUUID2 = Foundation.UUID().uuidString

        uploadDeletion(uploadDeletionRequest: uploadDeletionRequest, deviceUUID: deviceUUID2, addUser: false)

        let expectedDeletionState = [
            uploadResult.request.fileUUID: true,
        ]

        self.sendDoneUploads(expectedNumberOfUploads: 1, deviceUUID:deviceUUID2, masterVersion: uploadResult.request.masterVersion + MasterVersionInt(1), sharingGroupId: sharingGroupId)
        
        let expectedSizes = [
            uploadResult.request.fileUUID: uploadResult.fileSize,
        ]

        self.getFileIndex(expectedFiles: [uploadResult.request], masterVersionExpected: uploadResult.request.masterVersion + MasterVersionInt(2), expectedFileSizes: expectedSizes, sharingGroupId: sharingGroupId, expectedDeletionState:expectedDeletionState)
    }
    
    // MARK: Undeletion tests
    
    func uploadUndelete(twice: Bool = false) {
        let deviceUUID = Foundation.UUID().uuidString
        
        // This file is going to be deleted.
        guard let uploadResult = uploadTextFile(deviceUUID:deviceUUID),
            let sharingGroupId = uploadResult.sharingGroupId else {
            XCTFail()
            return
        }
        
        sendDoneUploads(expectedNumberOfUploads: 1, deviceUUID:deviceUUID, sharingGroupId: sharingGroupId)
        
        var masterVersion:MasterVersionInt = uploadResult.request.masterVersion + MasterVersionInt(1)
        let uploadDeletionRequest = UploadDeletionRequest(json: [
            UploadDeletionRequest.fileUUIDKey: uploadResult.request.fileUUID,
            UploadDeletionRequest.fileVersionKey: uploadResult.request.fileVersion,
            UploadDeletionRequest.masterVersionKey: masterVersion,
            ServerEndpoint.sharingGroupIdKey: sharingGroupId
        ])!
        
        uploadDeletion(uploadDeletionRequest: uploadDeletionRequest, deviceUUID: deviceUUID, addUser: false)
        sendDoneUploads(expectedNumberOfUploads: 1, deviceUUID:deviceUUID, masterVersion: masterVersion, sharingGroupId: sharingGroupId)
        
        masterVersion += 1
        
        // Upload undeletion
        guard let _ = uploadTextFile(deviceUUID:deviceUUID, fileUUID: uploadResult.request.fileUUID, addUser: .no(sharingGroupId: sharingGroupId), fileVersion: 1, masterVersion: masterVersion, undelete: 1) else {
            XCTFail()
            return
        }
        
        if twice {
            guard let uploadResult2 = uploadTextFile(deviceUUID:deviceUUID, fileUUID: uploadResult.request.fileUUID, addUser: .no(sharingGroupId: sharingGroupId), fileVersion: 1, masterVersion: masterVersion, undelete: 1) else {
                XCTFail()
                return
            }
            
            // Check uploads-- make sure there is only one.
            getUploads(expectedFiles: [uploadResult2.request], deviceUUID:deviceUUID, expectedFileSizes: [uploadResult.request.fileUUID: uploadResult.fileSize], sharingGroupId:sharingGroupId)
        }
        
        sendDoneUploads(expectedNumberOfUploads: 1, deviceUUID:deviceUUID, masterVersion: masterVersion, sharingGroupId: sharingGroupId)
        
        // Get the file index and make sure the file is not marked as deleted.
        guard let fileIndex = getFileIndex(deviceUUID: deviceUUID, sharingGroupId: sharingGroupId) else {
            XCTFail()
            return
        }
        
        guard fileIndex.count == 1 else {
            XCTFail()
            return
        }
        
        XCTAssert(fileIndex[0].fileUUID == uploadResult.request.fileUUID)
        XCTAssert(fileIndex[0].deleted == false)
    }
    
    func testUploadUndeleteWorks() {
        uploadUndelete()
    }
    
    // Test that upload undelete 2x (without done uploads) doesn't fail.
    func textThatUploadUndeleteUploadTwiceWorks() {
        uploadUndelete(twice: true)
    }
}

extension FileControllerTests_UploadDeletion {
    static var allTests : [(String, (FileControllerTests_UploadDeletion) -> () throws -> Void)] {
        return [
            ("testThatUploadDeletionTransfersToUploads", testThatUploadDeletionTransfersToUploads),
            ("testThatCombinedUploadDeletionAndFileUploadWork", testThatCombinedUploadDeletionAndFileUploadWork),
            ("testThatUploadDeletionTwiceOfSameFileWorks", testThatUploadDeletionTwiceOfSameFileWorks),
            ("testThatUploadDeletionFollowedByDoneUploadsActuallyDeletes", testThatUploadDeletionFollowedByDoneUploadsActuallyDeletes),
            ("testThatDeletionOfDifferentVersionFails", testThatDeletionOfDifferentVersionFails),
            ("testThatDeletionOfUnknownFileUUIDFails", testThatDeletionOfUnknownFileUUIDFails),
            ("testThatDeletionFailsWhenMasterVersionDoesNotMatch", testThatDeletionFailsWhenMasterVersionDoesNotMatch),
            ("testThatDebugDeletionFromServerWorks", testThatDebugDeletionFromServerWorks),
            ("testThatUploadByOneDeviceAndDeletionByAnotherActuallyDeletes", testThatUploadByOneDeviceAndDeletionByAnotherActuallyDeletes),
            ("testUploadUndeleteWorks", testUploadUndeleteWorks),
            ("textThatUploadUndeleteUploadTwiceWorks", textThatUploadUndeleteUploadTwiceWorks)
        ]
    }
    
    func testLinuxTestSuiteIncludesAllTests() {
        linuxTestSuiteIncludesAllTests(testType:FileControllerTests_UploadDeletion.self)
    }
}
