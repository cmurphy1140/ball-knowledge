import SwiftUI

@main
struct BallKnowledgeApp: App {
    init() {
        #if DEBUG
        if FontCheck.wantsReport { FontCheck.printReport() }
        #endif
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
                RootView()
            }
            #else
            RootView()
            #endif
        }
    }
}
