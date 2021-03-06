//
//  SharingGroupRepository.swift
//  Server
//
//  Created by Christopher G Prince on 6/23/18.
//

// A sharing group is a group of users who are sharing a collection of files.

import Foundation
import LoggerAPI
import SyncServerShared

class SharingGroup : NSObject, Model {
    static let sharingGroupUUIDKey = "sharingGroupUUID"
    var sharingGroupUUID: String!
    
    static let sharingGroupNameKey = "sharingGroupName"
    var sharingGroupName: String!
    
    static let deletedKey = "deleted"
    var deleted:Bool!
    
    // Not a part of this table, but a convenience for doing joins with the MasterVersion table.
    static let masterVersionKey = "masterVersion"
    var masterVersion: MasterVersionInt!

    // Similarly, not part of this table. For doing joins.
    public static let permissionKey = "permission"
    public var permission:Permission?
    
    // Also not part of this table. For doing fetches of sharing group users for the sharing group.
    public var sharingGroupUsers:[SyncServerShared.SharingGroupUser]!

    static let accountTypeKey = "accountType"
    var accountType: String!

    static let owningUserIdKey = "owningUserId"
    var owningUserId:UserId?

    subscript(key:String) -> Any? {
        set {
            switch key {
            case SharingGroup.sharingGroupUUIDKey:
                sharingGroupUUID = newValue as! String?

            case SharingGroup.sharingGroupNameKey:
                sharingGroupName = newValue as! String?
            
            case SharingGroup.deletedKey:
                deleted = newValue as! Bool?

            case SharingGroup.masterVersionKey:
                masterVersion = newValue as! MasterVersionInt?
                
            case SharingGroup.permissionKey:
                permission = newValue as! Permission?
                
            case SharingGroup.accountTypeKey:
                accountType = newValue as! String?

            case SharingGroup.owningUserIdKey:
                owningUserId = newValue as! UserId?

            default:
                assert(false)
            }
        }
        
        get {
            return getValue(forKey: key)
        }
    }
    
    override init() {
        super.init()
    }
    
    func typeConvertersToModel(propertyName:String) -> ((_ propertyValue:Any) -> Any?)? {
        switch propertyName {
            case SharingGroup.deletedKey:
                return {(x:Any) -> Any? in
                    return (x as! Int8) == 1
                }
            case SharingGroupUser.permissionKey:
                return {(x:Any) -> Any? in
                    return Permission(rawValue: x as! String)
                }
            default:
                return nil
        }
    }
    
    func toClient() -> SyncServerShared.SharingGroup  {
        let clientGroup = SyncServerShared.SharingGroup()!
        clientGroup.sharingGroupUUID = sharingGroupUUID
        clientGroup.sharingGroupName = sharingGroupName
        clientGroup.deleted = deleted
        clientGroup.masterVersion = masterVersion
        clientGroup.permission = permission
        clientGroup.sharingGroupUsers = sharingGroupUsers
        
        Log.debug("accountType: \(String(describing: accountType))")
        
        if let accountType = accountType {
            clientGroup.cloudStorageType = AccountType(rawValue: accountType)?.cloudStorageType?.rawValue
        }

        return clientGroup
    }
}

class SharingGroupRepository: Repository, RepositoryLookup {
    private(set) var db:Database!
    
    required init(_ db:Database) {
        self.db = db
    }
    
    var tableName:String {
        return SharingGroupRepository.tableName
    }
    
    static var tableName:String {
        return "SharingGroup"
    }
    
    func upcreate() -> Database.TableUpcreateResult {
        let createColumns =
            "(sharingGroupUUID VARCHAR(\(Database.uuidLength)) NOT NULL, " +

            // A name for the sharing group-- assigned by the client app.
            "sharingGroupName VARCHAR(\(Database.maxSharingGroupNameLength)), " +
            
            // true iff sharing group has been deleted. Like file references in the FileIndex, I'm never going to actually delete sharing groups.
            "deleted BOOL NOT NULL, " +
            
            "UNIQUE (sharingGroupUUID))"
        
        let result = db.createTableIfNeeded(tableName: "\(tableName)", columnCreateQuery: createColumns)
        return result
    }
    
    enum LookupKey : CustomStringConvertible {
        case sharingGroupUUID(String)
        
        var description : String {
            switch self {
            case .sharingGroupUUID(let sharingGroupUUID):
                return "sharingGroupUUID(\(sharingGroupUUID))"
            }
        }
    }
    
    func lookupConstraint(key:LookupKey) -> String {
        switch key {
        case .sharingGroupUUID(let sharingGroupUUID):
            return "sharingGroupUUID = '\(sharingGroupUUID)'"
        }
    }
    
    enum AddResult {
        case success
        case error(String)
    }
    
    func add(sharingGroupUUID:String, sharingGroupName: String? = nil) -> AddResult {
        let insert = Database.PreparedStatement(repo: self, type: .insert)
        
        insert.add(fieldName: SharingGroup.sharingGroupUUIDKey, value: .string(sharingGroupUUID))
        insert.add(fieldName: SharingGroup.deletedKey, value: .bool(false))

        if let sharingGroupName = sharingGroupName {
            insert.add(fieldName: SharingGroup.sharingGroupNameKey, value: .string(sharingGroupName))
        }
        
        do {
            try insert.run()
            Log.info("Sucessfully created sharing group")
            return .success
        }
        catch (let error) {
            Log.error("Could not insert into \(tableName): \(error)")
            return .error("\(error)")
        }
    }

    func sharingGroups(forUserId userId: UserId, sharingGroupUserRepo: SharingGroupUserRepository, userRepo: UserRepository) -> [SharingGroup]? {
        let masterVersionTableName = MasterVersionRepository.tableName
        let sharingGroupUserTableName = SharingGroupUserRepository.tableName
        
        let query = "select \(tableName).sharingGroupUUID, \(tableName).sharingGroupName, \(tableName).deleted, \(masterVersionTableName).masterVersion, \(sharingGroupUserTableName).permission, \(sharingGroupUserTableName).owningUserId FROM \(tableName),\(sharingGroupUserTableName), \(masterVersionTableName) WHERE \(sharingGroupUserTableName).userId = \(userId) AND \(sharingGroupUserTableName).sharingGroupUUID = \(tableName).sharingGroupUUID AND \(tableName).sharingGroupUUID = \(masterVersionTableName).sharingGroupUUID"
        
        guard let owningUsers = userRepo.getOwningSharingGroupUsers(forSharingUserId: userId) else {
            Log.error("Failed calling getOwningSharingGroupUsers")
            return nil
        }
        
        guard let sharingGroups = self.sharingGroups(forSelectQuery: query, sharingGroupUserRepo: sharingGroupUserRepo) else {
            Log.error("Failed calling sharingGroups")
            return nil
        }
        
        for sharingGroup in sharingGroups {
            let owningUser = owningUsers.filter {sharingGroup.owningUserId != nil && $0.userId == sharingGroup.owningUserId}
            if owningUser.count == 1 {
                sharingGroup.accountType = owningUser[0].accountType.rawValue
            }
        }
        
        return sharingGroups
    }
    
    private func sharingGroups(forSelectQuery selectQuery: String, sharingGroupUserRepo: SharingGroupUserRepository) -> [SharingGroup]? {
        
        guard let select = Select(db:db, query: selectQuery, modelInit: SharingGroup.init, ignoreErrors:false) else {
            return nil
        }
        
        var result = [SharingGroup]()
        var errorGettingSgus = false
        
        select.forEachRow { rowModel in
            let sharingGroup = rowModel as! SharingGroup
            
            let sguResult = sharingGroupUserRepo.sharingGroupUsers(forSharingGroupUUID: sharingGroup.sharingGroupUUID)
            switch sguResult {
            case .sharingGroupUsers(let sgus):
                sharingGroup.sharingGroupUsers = sgus
            case .error(let error):
                Log.error(error)
                errorGettingSgus = true
                return
            }
            
            result.append(sharingGroup)
        }
        
        if !errorGettingSgus && select.forEachRowStatus == nil {
            return result
        }
        else {
            return nil
        }
    }
    
    enum MarkDeletionCriteria {
        case sharingGroupUUID(String)
        
        func toString() -> String {
            switch self {
            case .sharingGroupUUID(let sharingGroupUUID):
                return "\(SharingGroup.sharingGroupUUIDKey)='\(sharingGroupUUID)'"
            }
        }
    }
    
    func markAsDeleted(forCriteria criteria: MarkDeletionCriteria) -> Int64? {
        let query = "UPDATE \(tableName) SET \(SharingGroup.deletedKey)=1 WHERE " + criteria.toString()
        if db.connection.query(statement: query) {
            return db.connection.numberAffectedRows()
        }
        else {
            let error = db.error
            Log.error("Could not mark files as deleted in \(tableName): \(error)")
            return nil
        }
    }
    
    func update(sharingGroup: SharingGroup) -> Bool {
        let update = Database.PreparedStatement(repo: self, type: .update)
        
        guard let sharingGroupUUID = sharingGroup.sharingGroupUUID,
            let sharingGroupName = sharingGroup.sharingGroupName else {
            return false
        }
        
        update.add(fieldName: SharingGroup.sharingGroupNameKey, value: .string(sharingGroupName))
        update.where(fieldName: SharingGroup.sharingGroupUUIDKey, value: .string(sharingGroupUUID))
        
        do {
            try update.run()
        }
        catch (let error) {
            Log.error("Failed updating sharing group: \(error)")
            return false
        }
        
        return true
    }
}

