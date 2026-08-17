//
//  CloudKitSyncable.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 12/08/26.
//

import CloudKit
import Foundation

/// A type that can be persisted as a CloudKit record.
///
/// Conforming types describe how their properties map to and from a
/// `CKRecord`. Once a model conforms, `CloudKitManager`'s generic CRUD
protocol CloudKitSyncable {

    /// The CloudKit record type name (e.g. "House", "User", "ChoreModel").
    static var recordType: String { get }

    /// The underlying CloudKit record identifier.
    var recordID: CKRecord.ID? { get set }

    /// Writes this model's fields into `record`.
    func populate(record: CKRecord)

    /// Builds a model instance from a fetched record.
    init?(record: CKRecord)
}
