//
//  UploadFile.swift
//  SyncServer
//
//  Created by Christopher Prince on 2/4/17.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import XCTest
@testable import SyncServer
import SMCoreLib

class ServerAPI_UploadFile: TestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testUploadTextFile() {
        let masterVersion = getMasterVersion()
        _ = uploadFile(fileName: "UploadMe", fileExtension: "txt", mimeType: "text/plain", serverMasterVersion: masterVersion)
    }
    
    func testUploadJPEGFile() {
        let masterVersion = getMasterVersion()
        _ = uploadFile(fileName: "Cat", fileExtension: "jpg", mimeType: "image/jpeg", serverMasterVersion: masterVersion)
    }
    
    func testUploadTextFileWithNoAuthFails() {
        ServerNetworking.session.authenticationDelegate = nil
        _ = uploadFile(fileName: "UploadMe", fileExtension: "txt", mimeType: "text/plain", expectError: true)
    }
    
    func testUploadTwoFilesWithSameUUIDFails() {
        let masterVersion = getMasterVersion()
        let fileUUID = UUID().uuidString

        _ = uploadFile(fileName: "UploadMe", fileExtension: "txt", mimeType: "text/plain", fileUUID: fileUUID, serverMasterVersion: masterVersion)
        _ = uploadFile(fileName: "UploadMe", fileExtension: "txt", mimeType: "text/plain", fileUUID: fileUUID, serverMasterVersion: masterVersion, expectError: true)
    }
    
    func testParallelUploadsWork() {
        let masterVersion = getMasterVersion()

        let expectation1 = self.expectation(description: "upload1")
        let expectation2 = self.expectation(description: "upload2")
        let fileUUID1 = UUID().uuidString
        let fileUUID2 = UUID().uuidString
        Log.special("fileUUID1= \(fileUUID1); fileUUID2= \(fileUUID2)")
        
        _ = uploadFile(fileName: "UploadMe", fileExtension: "txt", mimeType: "text/plain", fileUUID:fileUUID1, serverMasterVersion: masterVersion, withExpectation:expectation1)
        
        _ = uploadFile(fileName: "UploadMe", fileExtension: "txt", mimeType: "text/plain", fileUUID:fileUUID2, serverMasterVersion: masterVersion, withExpectation:expectation2)

        waitForExpectations(timeout: 30.0, handler: nil)
    }
}
