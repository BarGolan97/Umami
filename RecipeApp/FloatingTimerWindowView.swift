import SwiftUI
import SwiftData

struct RecipeFloatingTimerWindowView: View {
    let key: StepWindowKey?
    
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var timerService = RecipeTimerService.shared
    
    @State private var loadedStep: Step?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let step = loadedStep {
                    VStack(spacing: 0) {
                        
                        // --- Top: Title and text ---
                        HStack(alignment: .top, spacing: 12) {
                            
                            // Image
                            StepImageView(localImageName: step.localImageName, imageURL: step.imageURL)
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .shadow(radius: 2)
                            
                            // Text
                            ScrollView(.vertical, showsIndicators: false) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("CURRENT STEP")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.secondary)
                                        .padding(.bottom, 2)
                                    
                                    if !step.text.isEmpty {
                                        Text(step.text)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(.primary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        .padding(.bottom, 10)
                        .frame(height: 100)
                        
                        // --- Bottom: Timer ---
                        VStack {
                            let availableHeight = geo.size.height - 100
                            let diameter = min(geo.size.width, availableHeight - 70)
                            
                            Spacer()
                            
                            InteractiveRecipeTimerView(
                                step: step,
                                timerService: timerService,
                                isFloating: true,
                                preferredDiameter: diameter > 0 ? diameter : 120
                            )
                            
                            Spacer().frame(height: 30)
                        }
                        .frame(width: geo.size.width, height: geo.size.height - 100)
                    }
                } else {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Loading timer...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(width: 280, height: 380)
        #if os(visionOS)
        .persistentSystemOverlays(.visible)
        #endif
        .onAppear {
            loadStep()
        }
        .onDisappear {
            // Clear the window instance when closed
            if let stepID = key?.stepID {
                timerService.clearWindowInstance(for: stepID)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: loadedStep)
    }
    
    private func loadStep() {
        guard let stepID = key?.stepID else { 
            loadedStep = nil
            return 
        }
        loadedStep = context.model(for: stepID) as? Step
    }
}

