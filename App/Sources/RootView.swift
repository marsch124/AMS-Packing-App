import SwiftUI
import PackingCore

/// The frame of the app: one screen at a time, and the tab bar under it.
struct RootView: View {
    @State private var section: AppSection = .home

    var body: some View {
        VStack(spacing: 0) {
            SectionScreen(section: section)
                .frame(maxWidth: 720)                 // the web app's column, on the Mac
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            TabBar(section: $section)
        }
        .background(Theme.bg.ignoresSafeArea())
    }
}

/// A placeholder for each section until its real screen is built.
private struct SectionScreen: View {
    let section: AppSection

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            SectionMark(section: section, size: 96, weight: 1.6)
                .foregroundStyle(section.color)
            Text(section.label)
                .font(.system(size: 34, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .accessibilityIdentifier("screen-title")
            if section == .home {
                Text("The new app, being built.")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        // A named container must say it CONTAINS its children, or it swallows
        // their identifiers and the tests cannot find anything inside it.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("screen-\(section.rawValue)")
    }
}

private struct TabBar: View {
    @Binding var section: AppSection

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(AppSection.allCases) { s in
                    Button { section = s } label: { TabButtonLabel(section: s, active: s == section) }
                        .buttonStyle(.plain)
                        .focusEffectDisabled()      // no keyboard ring round a tab on the Mac
                        .accessibilityIdentifier("tab-\(s.rawValue)")
                        .accessibilityLabel(s.label)
                        .accessibilityAddTraits(s == section ? .isSelected : [])
                }
            }
            // A quiet build marker in its own thin row, so it can never sit on
            // top of a tab's label.
            Text(AppInfo.version)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.muted.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 8)
                .allowsHitTesting(false)
                .accessibilityIdentifier("app-version")
        }
        .frame(maxWidth: 720)
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
        .padding(.bottom, 2)
        .background(Theme.card.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Theme.line.frame(height: 1) }
    }
}

private struct TabButtonLabel: View {
    let section: AppSection
    let active: Bool

    var body: some View {
        VStack(spacing: 3) {
            SectionMark(section: section, size: 24, weight: active ? 2.2 : 1.9)
                .foregroundStyle(active ? Color.white : section.color)
                .frame(width: 46, height: 30)
                .background(Capsule().fill(active ? section.color : section.color.opacity(0.14)))
            Text(section.label)
                .font(.system(size: 12.5, weight: active ? .heavy : .semibold))
                .foregroundStyle(active ? Theme.ink : Theme.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 54)
        .contentShape(Rectangle())
    }
}
