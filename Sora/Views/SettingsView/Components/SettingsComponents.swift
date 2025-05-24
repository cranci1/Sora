//
//  SettingsComponents.swift
//  Sora
//

import SwiftUI

internal struct SettingsSection<Content: View>: View {
    internal let title: String
    internal let footer: String?
    internal let content: Content
    
    internal init(title: String, footer: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content()
    }
    
    internal var body: some View {
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

internal struct SettingsRow: View {
    internal let icon: String
    internal let title: String
    internal var value: String? = nil
    internal var isExternal: Bool = false
    internal var textColor: Color = .primary
    internal var showDivider: Bool = true
    
    internal init(icon: String, title: String, value: String? = nil, isExternal: Bool = false, textColor: Color = .primary, showDivider: Bool = true) {
        self.icon = icon
        self.title = title
        self.value = value
        self.isExternal = isExternal
        self.textColor = textColor
        self.showDivider = showDivider
    }
    
    internal var body: some View {
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

internal struct SettingsToggleRow: View {
    internal let icon: String
    internal let title: String
    @Binding internal var isOn: Bool
    internal var showDivider: Bool = true
    
    internal init(icon: String, title: String, isOn: Binding<Bool>, showDivider: Bool = true) {
        self.icon = icon
        self.title = title
        self._isOn = isOn
        self.showDivider = showDivider
    }
    
    internal var body: some View {
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

internal struct SettingsPickerRow<T: Hashable>: View {
    internal let icon: String
    internal let title: String
    internal let options: [T]
    internal let optionToString: (T) -> String
    @Binding internal var selection: T
    internal var showDivider: Bool = true
    
    internal init(icon: String, title: String, options: [T], optionToString: @escaping (T) -> String, selection: Binding<T>, showDivider: Bool = true) {
        self.icon = icon
        self.title = title
        self.options = options
        self.optionToString = optionToString
        self._selection = selection
        self.showDivider = showDivider
    }
    
    internal var body: some View {
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

internal struct SettingsStepperRow: View {
    internal let icon: String
    internal let title: String
    @Binding internal var value: Double
    internal let range: ClosedRange<Double>
    internal let step: Double
    internal var formatter: (Double) -> String = { "\(Int($0))" }
    internal var showDivider: Bool = true
    
    internal init(icon: String, title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, formatter: @escaping (Double) -> String = { "\(Int($0))" }, showDivider: Bool = true) {
        self.icon = icon
        self.title = title
        self._value = value
        self.range = range
        self.step = step
        self.formatter = formatter
        self.showDivider = showDivider
    }
    
    internal var body: some View {
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