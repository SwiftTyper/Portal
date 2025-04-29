import SwiftUI

public enum portalLayer{
    case root
    case above
}

/// Drives the Portal floating layer for a given id, triggered by an optional identifiable item.
///
/// Use this view modifier to trigger and control a portal transition animation between
/// a source and destination view based on the presence of an identifiable item. The modifier
/// manages the floating overlay layer, animation timing, and transition state for the
/// specified `id`.
///
/// This follows the standard SwiftUI pattern requiring the item to be `Identifiable`.
///
/// - Parameters:
///   - id: A unique string identifier for the portal transition. This should match the `id` used for the corresponding portal source and destination.
///   - item: A `Binding<Optional<Item>>` where `Item` conforms to `Identifiable`. The transition activates when this binding contains a value and deactivates when it's `nil`.
///   - sourceProgress: The progress value representing the source state (default: 0).
///   - destinationProgress: The progress value representing the destination state (default: 0).
///   - animation: The animation to use for the transition (default: `.smooth(duration: 0.42, extraBounce: 0.2)`).
///   - animationDuration: The duration of the transition animation (default: 0.72).
///   - delay: A delay before the animation starts after the item becomes non-nil (default: 0.06).
///   - layer: Specifies the rendering layer for the transition (e.g., `.above`, `.root`). Default is `.above`.
///   - layerView: A closure that receives the unwrapped `Item` and returns the `View` content to be animated during the transition.
///   - completion: An optional closure called when the transition animation finishes. The `Bool` indicates the final state (`true` for active/item present, `false` for inactive/item nil).
///
/// Example usage (Transitioning into a Sheet with Boolean):
/// ```swift
/// // 1. Define the Sheet Content View
/// struct SettingsSheetView: View {
///     @Binding var showSheet: Bool // To allow dismissing from within
///     let portalID: String
///
///     var body: some View {
///         NavigationView { // Optional: For title/toolbar
///             VStack {
///                 HStack {
///                     Image(systemName: "gearshape.fill")
///                         .font(.largeTitle)
///                         // 1a. Mark the destination inside the sheet
///                         .portalDestination(id: portalID)
///                     Text("Settings")
///                         .font(.largeTitle)
///                 }
///                 .padding(.top, 40)
///
///                 // ... other settings content ...
///                 Spacer()
///             }
///             .toolbar {
///                 ToolbarItem(placement: .navigationBarLeading) {
///                     Button("Done") { showSheet = false } // Dismiss sheet
///                 }
///             }
///         }
///     }
/// }
///
/// // 2. Define the Main View
/// struct ContentView: View {
///     @State private var showSettingsSheet: Bool = false
///     let portalID = "settingsIconTransition"
///
///     var body: some View {
///         // 2a. Wrap in PortalContainer
///         PortalContainer {
///             VStack {
///                 HStack {
///                     Spacer()
///                     // 2b. Source View
///                     Image(systemName: "gearshape.fill")
///                         .font(.title)
///                         .padding()
///                         .portalSource(id: portalID) // Mark source
///                         .onTapGesture {
///                             showSettingsSheet = true // Trigger sheet & transition
///                         }
///                 }
///                 Spacer() // Main content area
///                 Text("Main Content")
///                 Spacer()
///             }
///             .padding()
///             // 2c. Apply the sheet modifier using the boolean binding
///             .sheet(isPresented: $showSettingsSheet) {
///                 SettingsSheetView(
///                     showSheet: $showSettingsSheet,
///                     portalID: portalID
///                 )
///             }
///             // 2d. Apply the portal transition modifier
///             .portalTransition(
///                 id: portalID,                   // Same ID
///                 isActive: $showSettingsSheet,   // Boolean binding
///                 animation: .smooth(duration: 0.5),
///                 animationDuration: 0.5
///             ) {
///                 // 2e. Define the floating layer (what animates)
///                 Image(systemName: "gearshape.fill")
///                     .font(.title) // Match source/destination styling
///             }
///         }
///     }
/// }
/// ```
@available(iOS 15.0, macOS 13.0, *)
public struct OptionalPortalTransitionModifier<Item: Identifiable, LayerView: View>: ViewModifier {
    public let id: String
    @Binding public var item: Item?
    public let sourceProgress: CGFloat
    public let destinationProgress: CGFloat
    public let animation: Animation
    public let animationDuration: TimeInterval
    public let delay: TimeInterval
    private let layer: portalLayer = .above
    public let layerView: (Item) -> LayerView
    public let completion: (Bool) -> Void
    
    @EnvironmentObject private var portalModel: CrossModel
    
    public init(
        id: String,
        item: Binding<Optional<Item>>,
        sourceProgress: CGFloat = 0,
        destinationProgress: CGFloat = 0,
        animation: Animation = .bouncy(duration: 0.3),
        animationDuration: TimeInterval = 0.3,
        delay: TimeInterval = 0.06,
//        layer: portalLayer = .above,
        layerView: @escaping (Item) -> LayerView,
        completion: @escaping (Bool) -> Void = { _ in }
    ) {
        self.id = id
        self._item = item
        self.sourceProgress = sourceProgress
        self.destinationProgress = destinationProgress
        self.animation = animation
        self.animationDuration = animationDuration
        self.delay = delay
//        self.layer = layer
        self.layerView = layerView
        self.completion = completion
    }
    
    // Helper to get the correct index based on layer
    private func findPortalInfoIndex() -> Int? {
        switch layer {
        case .above:
            return portalModel.info.firstIndex { $0.infoID == id }
        case .root:
            return portalModel.rootInfo.firstIndex { $0.infoID == id }
        }
    }
    
    public func body(content: Content) -> some View {
        content
            .onAppear {
                if !portalModel.info.contains(where: { $0.infoID == id }) && layer == .above {
                    portalModel.info.append(PortalInfo(id: id))
                }
                if !portalModel.rootInfo.contains(where: { $0.infoID == id }) && layer == .root {
                    portalModel.rootInfo.append(PortalInfo(id: id))
                }
            }
            .onChangeCompat(of: item != nil) { hasValue in // Trigger on presence/absence
                // Find index using helper
                guard let idx = findPortalInfoIndex() else { return }
                
                // Get the correct array based on layer
                var portalInfoArray: [PortalInfo] {
                    get {
                        switch layer {
                        case .above: return portalModel.info
                        case .root: return portalModel.rootInfo
                        }
                    }
                    set {
                        switch layer {
                        case .above: portalModel.info = newValue
                        case .root: portalModel.rootInfo = newValue
                        }
                    }
                }
                
                // Update common properties
                portalInfoArray[idx].initalized = true
                portalInfoArray[idx].animationDuration = animationDuration
                portalInfoArray[idx].sourceProgress = sourceProgress
                portalInfoArray[idx].destinationProgress = destinationProgress
                portalInfoArray[idx].completion = completion
                
                if hasValue, let unwrappedItem = item {
                    portalInfoArray[idx].layerView = AnyView(layerView(unwrappedItem))
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        withAnimation(animation) {
                            portalInfoArray[idx].animateView = true
                        }
                    }
                } else {
                    portalInfoArray[idx].hideView = false
                    withAnimation(animation) {
                        portalInfoArray[idx].animateView = false
                    }
                }
            }
    }
}

/// Drives the Portal floating layer for a given id.
///
/// Use this view modifier to trigger and control a portal transition animation between
/// a source and destination view. The modifier manages the floating overlay layer,
/// animation timing, and transition state for the specified `id`.
///
/// - Parameters:
///   - id: A unique string identifier for the portal transition. This should match the `id` used for the corresponding portal source and destination.
///   - isActive: A binding that triggers the transition when set to `true`.
///   - sourceProgress: The progress value for the source view (default: 0).
///   - destinationProgress: The progress value for the destination view (default: 0).
///   - animation: The animation to use for the transition (default: `.bouncy(duration: 0.3)`).
///   - animationDuration: The duration of the transition animation (default: 0.3).
///   - delay: The delay before starting the animation (default: 0.06).
///   - layer: A closure that returns the floating overlay view to animate.
///   - completion: A closure called when the transition completes, with a `Bool` indicating success.
///
/// Example usage (Toggling visibility):
/// ```swift
/// struct ProfileView: View {
///     @State private var showEnlargedAvatar: Bool = false
///     let portalID = "avatarTransition"
///
///     var body: some View {
///         // 1. Wrap in PortalContainer
///         PortalContainer {
///             VStack {
///                 // 2. Source View
///                 Image("avatar-small")
///                     .resizable()
///                     .frame(width: 50, height: 50)
///                     .clipShape(Circle())
///                     .portalSource(id: portalID) // Mark source
///                     .onTapGesture {
///                         showEnlargedAvatar = true // Activate transition
///                     }
///
///                 Spacer() // Layout space
///
///                 // 3. Destination View (conditionally shown)
///                 if showEnlargedAvatar {
///                     Image("avatar-large") // Could be the same image name
///                         .resizable()
///                         .frame(width: 200, height: 200)
///                         .clipShape(Circle())
///                         .portalDestination(id: portalID) // Mark destination
///                         .onTapGesture {
///                             showEnlargedAvatar = false // Deactivate transition
///                         }
///                 } else {
///                     // Placeholder to maintain layout if needed
///                     Circle().fill(Color.clear).frame(width: 200, height: 200)
///                 }
///
///                 Spacer() // Layout space
///             }
///             .padding()
///             // 4. Apply the transition modifier
///             .portalTransition(
///                 id: portalID,               // Same ID
///                 isActive: $showEnlargedAvatar, // Boolean binding
///                 animation: .smooth(duration: 0.5),
///                 animationDuration: 0.5
///             ) {
///                 // 5. Define the floating layer (what animates)
///                 Image("avatar-small") // Or "avatar-large"
///                     .resizable()
///                     .aspectRatio(contentMode: .fill) // Ensure it fills during transition
///                     .clipShape(Circle()) // Match styling
///             }
///         }
///     }
/// }
/// ```
@available(iOS 15.0, macOS 13.0, *)
internal struct ConditionalPortalTransitionModifier<LayerView: View>: ViewModifier {
    public let id: String
    @Binding public var isActive: Bool
    public let sourceProgress: CGFloat
    public let destinationProgress: CGFloat
    public let animation: Animation
    public let animationDuration: TimeInterval
    public let delay: TimeInterval
    private let layer: portalLayer = .above
    public let layerView: () -> LayerView
    public let completion: (Bool) -> Void
    
    @EnvironmentObject private var portalModel: CrossModel
    
    // Initializer uses Binding<Bool>
    public init(
        id: String,
        isActive: Binding<Bool>, // Boolean binding
        sourceProgress: CGFloat = 0,
        destinationProgress: CGFloat = 0,
        animation: Animation = .bouncy(duration: 0.3),
        animationDuration: TimeInterval = 0.3,
        delay: TimeInterval = 0.06,
//        layer: portalLayer = .above,
        layerView: @escaping () -> LayerView, // No-argument closure
        completion: @escaping (Bool) -> Void = { _ in }
    ) {
        self.id = id
        self._isActive = isActive
        self.sourceProgress = sourceProgress
        self.destinationProgress = destinationProgress
        self.animation = animation
        self.animationDuration = animationDuration
        self.delay = delay
//        self.layer = layer
        self.layerView = layerView
        self.completion = completion
    }
    
    // Helper to get the correct index based on layer
    private func findPortalInfoIndex() -> Int? {
        switch layer {
        case .above:
            return portalModel.info.firstIndex { $0.infoID == id }
        case .root:
            return portalModel.rootInfo.firstIndex { $0.infoID == id }
            // Add other cases if portalLayer has more options
        }
    }
    
    public func body(content: Content) -> some View {
        content
            .onAppear {
                // Registration logic (remains the same)
                if !portalModel.info.contains(where: { $0.infoID == id }) && layer == .above {
                    portalModel.info.append(PortalInfo(id: id))
                }
                if !portalModel.rootInfo.contains(where: { $0.infoID == id }) && layer == .root {
                    portalModel.rootInfo.append(PortalInfo(id: id))
                }
            }
            .onChangeCompat(of: isActive) { newValue in
                // Find index using helper
                guard let idx = findPortalInfoIndex() else { return }
                
                // Get the correct array based on layer
                var portalInfoArray: [PortalInfo] {
                    get {
                        switch layer {
                        case .above: return portalModel.info
                        case .root: return portalModel.rootInfo
                        }
                    }
                    set {
                        switch layer {
                        case .above: portalModel.info = newValue
                        case .root: portalModel.rootInfo = newValue
                        }
                    }
                }
                
                // Update common properties
                portalInfoArray[idx].initalized = true
                portalInfoArray[idx].animationDuration = animationDuration
                portalInfoArray[idx].sourceProgress = sourceProgress
                portalInfoArray[idx].destinationProgress = destinationProgress
                portalInfoArray[idx].completion = completion
                portalInfoArray[idx].layerView = AnyView(layerView())
                
                if newValue {
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        withAnimation(animation) {
                            portalInfoArray[idx].animateView = true
                        }
                    }
                } else {
                    portalInfoArray[idx].hideView = false
                    withAnimation(animation) {
                        portalInfoArray[idx].animateView = false
                    }
                    
                }
            }
    }
}


@available(iOS 15.0, macOS 13.0, *)
public extension View {
    
    /// Drives a portal animation triggered by a boolean state.
    ///
    /// Attach this modifier to a container view to drive a portal transition between
    /// a source view (marked with `.portalSource`) and a destination view (marked with
    /// `.portalDestination`). The modifier manages the floating overlay, animation,
    /// and transition state for the specified `id` based on the `isActive` binding.
    ///
    /// The entire view hierarchy involved in the transition should be wrapped in a `PortalContainer`.
    ///
    /// - Parameters:
    ///   - id: A unique string identifier for the portal transition. Must match the `id` used for the corresponding portal source and destination.
    ///   - isActive: A `Binding<Bool>` that triggers the transition. `true` activates the transition, `false` deactivates it.
    ///   - sourceProgress: The progress value representing the source state (default: 0).
    ///   - destinationProgress: The progress value representing the destination state (default: 0).
    ///   - animation: The animation to use for the transition (default: `.smooth(duration: 0.42, extraBounce: 0.2)`).
    ///   - animationDuration: The duration of the transition animation (default: 0.72).
    ///   - delay: A delay before the animation starts after the trigger changes (default: 0.06).
    ///   - layer: Specifies the rendering layer for the transition (e.g., `.above`, `.root`). Default is `.above`.
    ///   - layerView: A closure returning the `View` content to be animated during the transition (the floating layer). This closure takes no arguments.
    ///   - completion: An optional closure called when the transition animation finishes. The `Bool` indicates the final state (`true` for active, `false` for inactive).
    ///
    ///Example usage (Transitioning into a Sheet with Boolean):
    /// ```swift
    /// // 1. Define the Sheet Content View
    /// struct SettingsSheetView: View {
    ///     @Binding var showSheet: Bool // To allow dismissing from within
    ///     let portalID: String
    ///
    ///     var body: some View {
    ///         NavigationView { // Optional: For title/toolbar
    ///             VStack {
    ///                 HStack {
    ///                     Image(systemName: "gearshape.fill")
    ///                         .font(.largeTitle)
    ///                         // 1a. Mark the destination inside the sheet
    ///                         .portalDestination(id: portalID)
    ///                     Text("Settings")
    ///                         .font(.largeTitle)
    ///                 }
    ///                 .padding(.top, 40)
    ///
    ///                 // ... other settings content ...
    ///                 Spacer()
    ///             }
    ///             .toolbar {
    ///                 ToolbarItem(placement: .navigationBarLeading) {
    ///                     Button("Done") { showSheet = false } // Dismiss sheet
    ///                 }
    ///             }
    ///         }
    ///     }
    /// }
    ///
    /// // 2. Define the Main View
    /// struct ContentView: View {
    ///     @State private var showSettingsSheet: Bool = false
    ///     let portalID = "settingsIconTransition"
    ///
    ///     var body: some View {
    ///         // 2a. Wrap in PortalContainer
    ///         PortalContainer {
    ///             VStack {
    ///                 HStack {
    ///                     Spacer()
    ///                     // 2b. Source View
    ///                     Image(systemName: "gearshape.fill")
    ///                         .font(.title)
    ///                         .padding()
    ///                         .portalSource(id: portalID) // Mark source
    ///                         .onTapGesture {
    ///                             showSettingsSheet = true // Trigger sheet & transition
    ///                         }
    ///                 }
    ///                 Spacer() // Main content area
    ///                 Text("Main Content")
    ///                 Spacer()
    ///             }
    ///             .padding()
    ///             // 2c. Apply the sheet modifier using the boolean binding
    ///             .sheet(isPresented: $showSettingsSheet) {
    ///                 SettingsSheetView(
    ///                     showSheet: $showSettingsSheet,
    ///                     portalID: portalID
    ///                 )
    ///             }
    ///             // 2d. Apply the portal transition modifier
    ///             .portalTransition(
    ///                 id: portalID,                   // Same ID
    ///                 isActive: $showSettingsSheet,   // Boolean binding
    ///                 animation: .smooth(duration: 0.5),
    ///                 animationDuration: 0.5
    ///             ) {
    ///                 // 2e. Define the floating layer (what animates)
    ///                 Image(systemName: "gearshape.fill")
    ///                     .font(.title) // Match source/destination styling
    ///             }
    ///         }
    ///     }
    /// }
    /// ```
    func portalTransition<LayerView: View>(
        id: String,
        isActive: Binding<Bool>,
        sourceProgress: CGFloat = 0,
        destinationProgress: CGFloat = 0,
        animation: Animation = .smooth(duration: 0.42, extraBounce: 0.2),
        animationDuration: TimeInterval = 0.72,
        delay: TimeInterval = 0.06,
//        layer: portalLayer = .above,
        @ViewBuilder layerView: @escaping () -> LayerView,
        completion: @escaping (Bool) -> Void = { _ in }
    ) -> some View {
        self.modifier(
            ConditionalPortalTransitionModifier(
                id: id,
                isActive: isActive,
                sourceProgress: sourceProgress,
                destinationProgress: destinationProgress,
                animation: animation,
                animationDuration: animationDuration,
                delay: delay,
//                layer: layer,
                layerView: layerView,
                completion: completion
            )
        )
    }
    
    /// Drives the Portal floating layer for a given id, triggered by an optional identifiable item.
    ///
    /// Use this view modifier to trigger and control a portal transition animation between
    /// a source view (marked with `.portalSource`) and a destination view (marked with
    /// `.portalDestination`), often across different view hierarchies like sheets or
    /// navigation links. The transition activates based on the presence of an identifiable item.
    ///
    /// This follows the standard SwiftUI pattern requiring the item to be `Identifiable`.
    /// The entire view hierarchy involved in the transition should be wrapped in a `PortalContainer`.
    ///
    /// - Parameters:
    ///   - id: A unique string identifier for the portal transition. This must match the `id` used for the corresponding `.portalSource` and `.portalDestination`.
    ///   - item: A `Binding<Optional<Item>>` where `Item` conforms to `Identifiable`. The transition activates when this binding contains a value and deactivates when it's `nil`.
    ///   - sourceProgress: The progress value representing the source state (default: 0).
    ///   - destinationProgress: The progress value representing the destination state (default: 0).
    ///   - animation: The animation to use for the transition (default: `.smooth(duration: 0.42, extraBounce: 0.2)`).
    ///   - animationDuration: The duration of the transition animation (default: 0.72).
    ///   - delay: A delay before the animation starts after the item becomes non-nil (default: 0.06).
    ///   - layer: Specifies the rendering layer for the transition (e.g., `.above`, `.root`). Default is `.above`.
    ///   - layerView: A closure that receives the unwrapped `Item` and returns the `View` content to be animated during the transition (the floating layer).
    ///   - completion: An optional closure called when the transition animation finishes. The `Bool` indicates the final state (`true` for active/item present, `false` for inactive/item nil).
    ///
    /// Example usage (Transitioning into a Sheet):
    /// ```swift
    /// // 1. Define your identifiable item
    /// struct Book: Identifiable {
    ///     let id = UUID() // Conforms to Identifiable
    ///     let title: String
    ///     let coverImageName: String
    /// }
    ///
    /// // 2. Define the Detail View (presented in the sheet)
    /// struct BookDetailView: View {
    ///     let book: Book
    ///     let portalID: String // To link the destination
    ///
    ///     var body: some View {
    ///         VStack {
    ///             Image(book.coverImageName)
    ///                 .resizable()
    ///                 .scaledToFit()
    ///                 .frame(height: 300)
    ///                 .clipShape(RoundedRectangle(cornerRadius: 8))
    ///                 // 2a. Mark the destination view inside the sheet
    ///                 .portalDestination(id: portalID)
    ///
    ///             Text(book.title).font(.title)
    ///             // ... other details ...
    ///             Spacer()
    ///         }
    ///         .padding()
    ///     }
    /// }
    ///
    /// // 3. Define the Main View (List)
    /// struct LibraryView: View {
    ///     @State private var selectedBook: Book?
    ///     let books: [Book] = [ /* ... your array of books ... */ ]
    ///     let portalID = "bookCoverTransition" // Shared ID for source, dest, transition
    ///
    ///     var body: some View {
    ///         // 3a. Wrap the relevant hierarchy in a PortalContainer
    ///         PortalContainer {
    ///             ScrollView {
    ///                 LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))]) {
    ///                     ForEach(books) { book in
    ///                         Image(book.coverImageName)
    ///                             .resizable()
    ///                             .scaledToFit()
    ///                             .frame(height: 150)
    ///                             .clipShape(RoundedRectangle(cornerRadius: 4))
    ///                             // 3b. Mark the source view in the list
    ///                             .portalSource(id: portalID)
    ///                             .onTapGesture {
    ///                                 selectedBook = book // Trigger sheet & transition
    ///                             }
    ///                     }
    ///                 }
    ///                 .padding()
    ///             }
    ///             // 3c. Apply the sheet modifier using the item binding
    ///             .sheet(item: $selectedBook) { book in
    ///                 // Present the detail view when selectedBook is not nil
    ///                 BookDetailView(book: book, portalID: portalID)
    ///             }
    ///             // 3d. Apply the portal transition modifier to drive the animation
    ///             .portalTransition(
    ///                 id: portalID,               // Same ID as source/destination
    ///                 item: $selectedBook,        // Binding to the optional item
    ///                 animation: .smooth(duration: 0.6),
    ///                 animationDuration: 0.6
    ///             ) { book in
    ///                 // 3e. Define the floating layer view (what actually animates)
    ///                 Image(book.coverImageName)
    ///                     .resizable()
    ///                     .scaledToFit()
    ///                     // Match styling of source/destination for seamlessness
    ///                     .clipShape(RoundedRectangle(cornerRadius: 4)) // Match list item corner
    ///             }
    ///         }
    ///     }
    /// }
    /// ```
    func portalTransition<Item: Identifiable, LayerView: View>(
        id: String,
        item: Binding<Optional<Item>>,
        sourceProgress: CGFloat = 0,
        destinationProgress: CGFloat = 0,
        animation: Animation = .smooth(duration: 0.42, extraBounce: 0.2),
        animationDuration: TimeInterval = 0.72,
        delay: TimeInterval = 0.06,
//        layer: portalLayer = .above,
        @ViewBuilder layerView: @escaping (Item) -> LayerView,
        completion: @escaping (Bool) -> Void = { _ in }
    ) -> some View {
        self.modifier(
            OptionalPortalTransitionModifier(
                id: id,
                item: item,
                sourceProgress: sourceProgress,
                destinationProgress: destinationProgress,
                animation: animation,
                animationDuration: animationDuration,
                delay: delay,
//                layer: layer,
                layerView: layerView,
                completion: completion
            )
        )
    }
}
