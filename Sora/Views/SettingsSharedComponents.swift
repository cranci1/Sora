//
//  SettingsSharedComponents.swift
//  Sora
//

import SwiftUI

// MARK: - Settings Section
struct SettingsSection<Content: View>: View {
    let title: String
    let footer: String?
    let content: Content
    
    init(title: String, footer: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.footnote)
                .foregroundStyle(.gray)
                .padding(.horizontal, 20)
            
            VStack(spacing: 0) {
                content
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color.accentColor.opacity(0.3), location: 0),
                                .init(color: Color.accentColor.opacity(0), location: 1)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
            )
            .padding(.horizontal, 20)
            
            if let footer = footer {
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(.gray)
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
            }
        }
    }
}

// MARK: - Settings Row
struct SettingsRow: View {
    let icon: String
    let title: String
    var value: String? = nil
    var isExternal: Bool = false
    var textColor: Color = .primary
    var showDivider: Bool = true
    
    init(icon: String, title: String, value: String? = nil, isExternal: Bool = false, textColor: Color = .primary, showDivider: Bool = true) {
        self.icon = icon
        self.title = title
        self.value = value
        self.isExternal = isExternal
        self.textColor = textColor
        self.showDivider = showDivider
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 24, height: 24)
                    .foregroundStyle(textColor)
                
                Text(title)
                    .foregroundStyle(textColor)
                
                Spacer()
                
                if let value = value {
                    Text(value)
                        .foregroundStyle(.gray)
                }
                
                if isExternal {
                    Image(systemName: "arrow.up.forward")
                        .foregroundStyle(.gray)
                        .font(.footnote)
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.gray)
                        .font(.footnote)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            if showDivider {
                Divider()
                    .padding(.horizontal, 16)
            }
        }
    }
}

// MARK: - Settings Toggle Row
struct SettingsToggleRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool
    var showDivider: Bool = true
    
    init(icon: String, title: String, isOn: Binding<Bool>, showDivider: Bool = true) {
        self.icon = icon
        self.title = title
        self._isOn = isOn
        self.showDivider = showDivider
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 24, height: 24)
                    .foregroundStyle(.primary)
                
                Text(title)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .tint(.accentColor)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            if showDivider {
                Divider()
                    .padding(.horizontal, 16)
            }
        }
    }
}

// MARK: - Settings Picker Row
struct SettingsPickerRow<T: Hashable>: View {
    let icon: String
    let title: String
    let options: [T]
    let optionToString: (T) -> String
    @Binding var selection: T
    var showDivider: Bool = true
    
    init(icon: String, title: String, options: [T], optionToString: @escaping (T) -> String, selection: Binding<T>, showDivider: Bool = true) {
        self.icon = icon
        self.title = title
        self.options = options
        self.optionToString = optionToString
        self._selection = selection
        self.showDivider = showDivider
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 24, height: 24)
                    .foregroundStyle(.primary)
                
                Text(title)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Menu {
                    ForEach(options, id: \.self) { option in
                        Button(action: { selection = option }) {
                            Text(optionToString(option))
                        }
                    }
                } label: {
                    Text(optionToString(selection))
                        .foregroundStyle(.gray)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            if showDivider {
                Divider()
                    .padding(.horizontal, 16)
            }
        }
    }
}

// MARK: - Settings Stepper Row
struct SettingsStepperRow: View {
    let icon: String
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    var formatter: (Double) -> String = { "\(Int($0))" }
    var showDivider: Bool = true
    
    init(icon: String, title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, formatter: @escaping (Double) -> String = { "\(Int($0))" }, showDivider: Bool = true) {
        self.icon = icon
        self.title = title
        self._value = value
        self.range = range
        self.step = step
        self.formatter = formatter
        self.showDivider = showDivider
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 24, height: 24)
                    .foregroundStyle(.primary)
                
                Text(title)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Stepper(formatter(value), value: $value, in: range, step: step)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            if showDivider {
                Divider()
                    .padding(.horizontal, 16)
            }
        }
    }
} 