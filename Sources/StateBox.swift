import SwiftUI

/// Use `@StateBox` instead of `@State`. In the macOS 27 SDK `@State` is a
/// macro whose plugin ships only with Xcode; naming the type through an alias
/// selects the property wrapper, so the app builds
/// with the Command Line Tools alone.
typealias StateBox = SwiftUI.State
