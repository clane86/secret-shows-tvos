//
//  News_JunkieApp.swift
//  News Junkie
//
//  Created by Chris Lane on 3/15/26.
//

import SwiftUI

@main
struct News_JunkieApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appModel)
                .task {
                    appModel.bootstrap()
                }
                .onChange(of: scenePhase) { newPhase in
                    appModel.handleScenePhase(newPhase)
                }
        }
    }
}
