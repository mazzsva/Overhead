//
//  EntrySheet.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 12/10/26.
//

import ComposableArchitecture
import SwiftUI

enum SheetCancellation {
    case back
    case cancel

    fileprivate var systemImage: String {
        switch self {
        case .back: "chevron.backward"
        case .cancel: "xmark"
        }
    }

    fileprivate var title: LocalizedStringResource {
        switch self {
        case .back: "Back"
        case .cancel: "Cancel"
        }
    }
}

enum SheetConfirmation {
    case button(LocalizedStringResource)
    case checkmark
}

struct EntrySheet<Content: View, Accessory: View>: View {
    let title: Text
    let accent: Accent
    var cancellation = SheetCancellation.cancel
    var confirmation = SheetConfirmation.checkmark
    let canConfirm: Bool
    let locale: Locale
    let onCancellation: () -> Void
    let onConfirmation: () -> Void
    @ViewBuilder let content: Content
    @ViewBuilder let accessory: Accessory

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        VStack(spacing: 10) {
                            content
                        }
                        .padding(.top, 32)
                        Spacer(minLength: 32)
                        VStack(spacing: 12) {
                            accessory
                            if case .button(let title) = confirmation {
                                ProminentButton(title: title, accent: accent, action: onConfirmation)
                                    .disabled(!canConfirm)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                    .tint(accent.color)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .background {
                SheetGlow(gradient: accent.glow)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if case .checkmark = confirmation {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save", systemImage: "checkmark", action: onConfirmation)
                            .labelStyle(.iconOnly)
                            .disabled(!canConfirm)
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: onCancellation) {
                        Label {
                            Text(cancellation.title)
                        } icon: {
                            Image(systemName: cancellation.systemImage)
                        }
                    }
                    .labelStyle(.iconOnly)
                    .contentTransition(reduceMotion ? .opacity : .symbolEffect(.replace))
                    .foregroundStyle(.secondary)
                }
            }
        }
        .environment(\.locale, locale)
    }
}

struct SheetCaption: View {
    enum Tone {
        case error
        case info
        case warning
    }

    let tone: Tone
    let text: Text

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            switch tone {
            case .error:
                text.foregroundStyle(Color.critical)
            case .info:
                text.foregroundStyle(.secondary)
            case .warning:
                Label {
                    text
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
        }
        .font(.callout)
        .multilineTextAlignment(.center)
        .transition(.replace(reducingMotion: reduceMotion))
    }
}

private struct SheetGlow: View {
    let gradient: Gradient

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Color(.systemGroupedBackground)
            .overlay(alignment: .top) {
                LinearGradient(gradient: gradient, startPoint: .leading, endPoint: .trailing)
                    .frame(height: 340)
                    .mask {
                        LinearGradient(
                            colors: [.black, .black.opacity(0.4), .clear], startPoint: .top, endPoint: .bottom)
                    }
                    .blur(radius: 48)
                    .opacity(colorScheme == .dark ? 0.3 : 0.24)
                    .animation(.glow(reducingMotion: reduceMotion), value: gradient)
            }
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}
