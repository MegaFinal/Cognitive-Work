//  DebugExtension.swift
//  Cognitive-Work
//
//  Local-only debug utilities for CloudKitManager. Not tracked by git — see .gitignore.
//

import CloudKit

/// Destructive, irreversible debug utilities for wiping test data during development.
///
/// Nothing in the app calls these automatically; invoke them manually (e.g. from a
/// debug button you wire up yourself) when you need a clean CloudKit database.
