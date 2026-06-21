import SwiftUI
import UIKit

// MARK: - Background

struct QSBackground: View {
    var body: some View {
        LinearGradient(colors: Palette.bg, startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }
}

// MARK: - Buttons

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded))
            .foregroundStyle(.white)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity)
            .background(LinearGradient.brand, in: Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
            .shadow(color: Palette.brand.opacity(0.35), radius: 10, y: 5)
    }
}

/// Circular icon button on a material chip (toolbar-style).
struct CircleIconButton: View {
    let system: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .frame(width: 42, height: 42)
                .background(Palette.card, in: Circle())
                .overlay(Circle().stroke(Palette.separator, lineWidth: 1))
        }
    }
}

// MARK: - Async image from ImageStore

/// Loads an image off the main thread and shows a placeholder until ready.
/// Bump `refresh` to force a reload after the file changes (e.g. after editing).
struct StoredImage: View {
    let id: UUID
    var kind: ImageStore.Kind = .thumb
    var contentMode: ContentMode = .fill
    var refresh: Int = 0
    @State private var image: UIImage?

    private struct Key: Hashable { let id: UUID; let kind: String; let refresh: Int }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().aspectRatio(contentMode: contentMode)
            } else {
                Rectangle().fill(Palette.brandSoft)
                    .overlay(Image(systemName: "doc.text.image").font(.title2).foregroundStyle(Palette.brand.opacity(0.5)))
            }
        }
        .task(id: Key(id: id, kind: kind.rawValue, refresh: refresh)) { await load() }
    }

    private func load() async {
        let target = id, k = kind
        let img = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            ImageStore.shared.load(target, k) ?? ImageStore.shared.displayImage(target)
        }.value
        if !Task.isCancelled { image = img }
    }
}

// MARK: - Filter selector

struct FilterBar: View {
    @Binding var selection: FilterMode
    var lang: AppLanguage
    var onChange: (FilterMode) -> Void = { _ in }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(FilterMode.allCases) { mode in
                let on = mode == selection
                Button {
                    selection = mode
                    onChange(mode)
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: mode.icon).font(.system(size: 16, weight: .semibold))
                        Text(mode.title(lang)).font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .foregroundStyle(on ? .white : Palette.sub)
                    .background {
                        if on {
                            RoundedRectangle(cornerRadius: 14, style: .continuous).fill(LinearGradient.brand)
                        } else {
                            RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.card)
                                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Palette.separator, lineWidth: 1))
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Empty state

struct EmptyState: View {
    let icon: String
    let title: String
    let subtitle: String
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 54, weight: .light))
                .foregroundStyle(Palette.brand.opacity(0.7))
            Text(title)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(Palette.ink)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(Palette.sub)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 44)
        }
    }
}

// MARK: - Processing overlay

struct ProcessingOverlay: View {
    let text: String
    var body: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView().controlSize(.large).tint(Palette.brand)
                Text(text).font(.system(.subheadline, design: .rounded).weight(.medium)).foregroundStyle(Palette.ink)
            }
            .padding(28)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }
}

// MARK: - Share sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

// MARK: - Helpers

extension Date {
    func qsShort() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: AppLanguage.current.rawValue)
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: self)
    }
}

extension View {
    /// Hide the keyboard from anywhere.
    func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
