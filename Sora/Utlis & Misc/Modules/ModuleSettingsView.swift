//
//  ModuleSettingsView.swift
//  Sulfur
//
//  Created by Francesco on 14/07/26.
//

import SwiftUI

struct ModuleSettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var moduleManager: ModuleManager
    @Environment(\.colorScheme) var colorScheme
    
    let module: Module
    
    @State private var settings: [ModuleSetting] = []
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    colorScheme == .dark ? Color.black : Color.white,
                    Color.accentColor.opacity(0.05)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Capsule()
                        .frame(width: 40, height: 5)
                        .foregroundColor(Color(.systemGray3))
                        .padding(.top, 10)
                    Spacer()
                }
                .padding(.bottom, 8)
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(module.metadata.sourceName)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                        Text(NSLocalizedString("Module Settings", comment: ""))
                            .font(.footnote)
                            .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.6) : Color.black.opacity(0.5))
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                
                ScrollView(showsIndicators: false) {
                    if settings.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "gearshape")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text(NSLocalizedString("No Settings", comment: ""))
                                .font(.headline)
                            Text(NSLocalizedString("This module doesn't expose any editable settings.", comment: ""))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 40)
                        .frame(maxWidth: .infinity)
                    } else {
                        VStack(spacing: 0) {
                            ForEach($settings) { $setting in
                                ModuleSettingRow(setting: $setting)
                                
                                if setting.id != settings.last?.id {
                                    Divider()
                                        .padding(.horizontal, 16)
                                }
                            }
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
                    }
                }
                .padding(.bottom, 12)
                
                VStack(spacing: 10) {
                    Button(action: save) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(colorScheme == .dark ? .black : .white)
                            Text(NSLocalizedString("Save Settings", comment: ""))
                        }
                        .font(.headline)
                        .foregroundColor(colorScheme == .dark ? .black : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    colorScheme == .dark ? Color.white : Color.black,
                                    colorScheme == .dark ? Color.white.opacity(0.9) : Color.black.opacity(0.9)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                        )
                        .shadow(
                            color: colorScheme == .dark
                            ? Color.black.opacity(0.3)
                            : Color.accentColor.opacity(0.25),
                            radius: 8, x: 0, y: 4
                        )
                        .padding(.horizontal, 20)
                    }
                    .disabled(settings.isEmpty)
                    .opacity(settings.isEmpty ? 0.6 : 1)
                    
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Text(NSLocalizedString("Cancel", comment: ""))
                            .font(.body)
                            .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.7) : Color.black.opacity(0.6))
                            .padding(.vertical, 8)
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            settings = moduleManager.getModuleSettings(module)
        }
    }
    
    private func save() {
        moduleManager.updateModuleSettings(module, settings: settings)
        DropManager.shared.showDrop(
            title: NSLocalizedString("Settings Saved", comment: ""),
            subtitle: "",
            duration: 1.5,
            icon: UIImage(systemName: "checkmark.circle.fill")
        )
        presentationMode.wrappedValue.dismiss()
    }
}

private struct ModuleSettingRow: View {
    @Binding var setting: ModuleSetting
    
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(setting.key)
                    .foregroundStyle(.primary)
                
                if setting.comment != nil {
                    Text(setting.comment!)
                        .font(.caption2)
                        .foregroundStyle(.gray)
                }
            }
            
            Spacer()
            
            control
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    @ViewBuilder
    private var control: some View {
        if let options = setting.options, !options.isEmpty {
            Menu {
                ForEach(options, id: \.self) { option in
                    Button(option) { setting.value = option }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(setting.value.isEmpty ? NSLocalizedString("Select", comment: "") : setting.value)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            switch setting.type {
            case .bool:
                Toggle("", isOn: Binding(
                    get: { setting.value.lowercased() == "true" },
                    set: { setting.value = $0 ? "true" : "false" }
                ))
                .labelsHidden()
                .tint(.accentColor.opacity(0.7))
            case .int:
                TextField("0", text: $setting.value)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
            case .float:
                TextField("0.0", text: $setting.value)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
            case .string:
                TextField(NSLocalizedString("Value", comment: ""), text: $setting.value)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 160)
            }
        }
    }
}
