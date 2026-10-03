import SwiftUI
import SwiftData

#if os(macOS)
import AppKit
#endif

@main
struct RecipeApp: App {
    let container: ModelContainer

    @State private var forceUpdate = ForceUpdateManager.shared

    init() {
        do {
            // Recipe cloud sync is handled manually via CloudKitManager (public database),
            // so disable SwiftData's automatic CloudKit mirroring. Leaving it on tries to
            // mirror to the private database using an out-of-date Production schema, which
            // spams "Cannot create or modify field 'CD_…'" errors and does nothing useful.
            let config = ModelConfiguration(isStoredInMemoryOnly: false, cloudKitDatabase: .none)
            container = try ModelContainer(
                for: Recipe.self, Ingredient.self, Step.self, CookingSession.self, ShoppingItem.self, RecipeHistoryEntry.self,
                configurations: config
            )
        } catch {
            fatalError("Failed to create SwiftData container: \(error)")
        }
    }
    
    var body: some Scene {
        // --- 1. החלון הראשי ---
        WindowGroup(id: "main") {
            MainWindowWrapper {
                MainTabView()
                    .onAppear {
                        Task {
                            // Check whether this version is still allowed before anything else.
                            await ForceUpdateManager.shared.checkForRequiredUpdate()

                            // Seed the bundled recipes, then sync the rest from CloudKit.
                            RecipeSeeder.seedBuiltInRecipes(modelContext: container.mainContext)
                            RecipeSeeder.migrateDefaultServings(modelContext: container.mainContext)

                            print("🔄 Fetching recipes from CloudKit...")
                            await CloudKitManager.shared.fetchAllRecipes(modelContext: container.mainContext)
                            print("✅ Recipes synced!")
                        }
                    }
                    .frame(minWidth: 1280, minHeight: 720)
                    .overlay {
                        if forceUpdate.updateRequired {
                            ForceUpdateView(
                                message: forceUpdate.updateMessage,
                                appStoreURL: forceUpdate.appStoreURL
                            )
                        }
                    }
            }
            
        }
        // זה גורם לחלון להיפתח בדיוק בגודל של התוכן (HomeView)
        .windowResizability(.contentSize)
        .modelContainer(container)
        .environment(EntitlementManager.shared)
        .environment(AIUsageManager.shared)
        .handlesExternalEvents(matching: ["*"])

        // --- 2. חלון הטיימר הצף ---
        WindowGroup(id: "floatingTimer", for: StepWindowKey.self) { $key in
            RecipeFloatingTimerWindowView(key: key)
                #if os(macOS)
                // כאן הגודל ידוע מראש (280x380) אז אנחנו נועלים אותו + מביאים לחזית
                .background(FloatingTimerWindowConfigurator())
                #endif
        }
        .defaultSize(width: 280, height: 380)
        .windowResizability(.contentSize)
        .modelContainer(container)
        .environment(EntitlementManager.shared)
        .environment(AIUsageManager.shared)
        .handlesExternalEvents(matching: [])
    }
}

// MARK: - רכיב עזר לניהול סגירת חלונות
struct MainWindowWrapper<Content: View>: View {
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.scenePhase) private var scenePhase
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .onDisappear {
                dismissWindow(id: "floatingTimer")
                RecipeTimerService.shared.stopAll()
            }
            .onChange(of: scenePhase) { newPhase in
                switch newPhase {
                case .inactive, .background:
                    dismissWindow(id: "floatingTimer")
                    RecipeTimerService.shared.stopAll()
                default:
                    break
                }
            }
    }
}
