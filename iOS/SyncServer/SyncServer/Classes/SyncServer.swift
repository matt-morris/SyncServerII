//
//  SyncServer.swift
//  SyncServer
//
//  Created by Christopher Prince on 2/23/17.
//
//

import Foundation
import SMCoreLib

// TODO: *1* These delegate methods are called on the main thread.

public protocol SMSyncServerDelegate : class {
    /* Called at the end of all downloads, on non-error conditions. Only called when there was at least one download.
    The client owns the files referenced by the NSURL's after this call completes. These files are temporary in the sense that they will not be backed up to iCloud, could be removed when the device or app is restarted, and should be moved to a more permanent location. This is received/called in an atomic manner: This reflects the current state of files on the server.
    The recommended action is for the client to replace their existing data with that from the files.
    */
    func syncServerShouldSaveDownloads(downloads: [(downloadedFile: NSURL, downloadedFileAttributes: SyncAttributes)])
}

public class SyncServer {
    public static let session = SyncServer()
    
    private init() {
    }
    
    public func appLaunchSetup(withServerURL serverURL: URL) {
        Network.session().appStartup()

        ServerAPI.session.baseURL = serverURL.absoluteString

        // This seems a little hacky, but can't find a better way to get the bundle of the framework containing our model. I.e., "this" framework. Just using a Core Data object contained in this framework to track it down.
        // Without providing this bundle reference, I wasn't able to dynamically locate the model contained in the framework.
        let bundle = Bundle(for: NSClassFromString(MasterVersion.entityName())!)
        
        let coreDataSession = CoreData(namesDictionary: [
            CoreDataModelBundle: bundle,
            CoreDataBundleModelName: "Client",
            CoreDataSqlliteBackupFileName: "~Client.sqlite",
            CoreDataSqlliteFileName: "Client.sqlite"
        ]);
        
        CoreData.registerSession(coreDataSession, forName: Constants.coreDataName)
    }
}
