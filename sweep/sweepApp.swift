//
//  sweepApp.swift
//  sweep
//
//  Created by Rasmus Hauschild on 02/05/2026.
//

import SwiftUI

@main
struct sweepApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
