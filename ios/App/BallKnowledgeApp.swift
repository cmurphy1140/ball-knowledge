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
            } else {
                RootView()
            }
            #else
            RootView()
            #endif
        }
    }
}
