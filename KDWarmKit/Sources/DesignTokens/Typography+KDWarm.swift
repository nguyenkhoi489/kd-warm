import SwiftUI

/// Type tokens (design-guidelines §2). System fonts only — SF Pro for UI, SF Mono
/// for domains / paths / versions / logs. Do not bundle web fonts.
public enum KDFont {
    public static let title: Font = .title2.weight(.semibold)
    public static let headline: Font = .headline
    public static let body: Font = .body
    public static let subheadline: Font = .subheadline
    public static let footnote: Font = .footnote
    public static let mono: Font = .system(.body, design: .monospaced)
}
