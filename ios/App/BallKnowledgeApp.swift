import SwiftUI

@main
struct BallKnowledgeApp: App {
    /// The model the launch arguments asked for, built once: the bundled data read, the save
    /// loaded and settled, a screenshot state seeded (see Model/ScreenshotState.swift).
    @State private var launch: AppLaunch

    init() {
        #if DEBUG
        if FontCheck.wantsReport { FontCheck.printReport() }
        #endif
        _launch = State(initialValue: AppLaunch.make(options: LaunchOptions(arguments: ProcessInfo.processInfo.arguments)))
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if FontCheck.wantsSpecimen {
                FontSpecimenView()
            } else if let page = GalleryPage.fromLaunchArguments {
                // Design-system gallery: -BKGallery <page> (see Debug/Gallery.swift).
                GalleryView(page: page)
            } else {
                app
            }
            #else
            app
            #endif
        }
    }

    @ViewBuilder
    private var app: some View {
        switch launch {
        case .ready(let model):
            RootView()
                .environment(model)
        case .failed(let reason):
            LaunchFailureView(reason: reason)
        }
    }
}

/// Shown only when the bundled data cannot be read: the app cannot play without it.
private struct LaunchFailureView: View {
    let reason: String

    var body: some View {
        VStack(spacing: BKSpace.s8) {
            Text("The game data could not be read.")
                .font(BKText.body.weight(.semibold))
                .foregroundStyle(BKColor.ink)
            Text(reason)
                .font(BKText.footnote)
                .foregroundStyle(BKColor.ink2)
                .multilineTextAlignment(.center)
        }
        .padding(BKSpace.gutter)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BKColor.bg.ignoresSafeArea())
    }
}
