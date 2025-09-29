//
//  SnapPicApp.swift
//  SnapPic
//
//  Created by STUDENT on 8/28/25.
//

import SwiftUI
import SwiftData
import FirebaseCore

@main
struct SnapPicApp: App {
    init() {
        FirebaseApp.configure()
    }
    @StateObject private var auth = AuthViewModel()
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            Group {
                if auth.isLoggedIn {
                    LayoutSelectionView()
                } else {
                    if auth.showSignUp {
                        SignUpView()
                    } else {
                        LoginView()
                    }
                }
            }
            .environmentObject(auth)
        }
        .modelContainer(sharedModelContainer)
    }
}
