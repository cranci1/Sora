import SwiftUI

struct IconSwitcherView: View {
    let icons = [
        (name: "Default Icon", iconName: nil), // Default app icon
        (name: "Alternate Icon", iconName: "AlternateIcon") // Alternate app icon
    ]
    
    var body: some View {
        List(icons, id: \.iconName) { icon in
            HStack {
                Text(icon.name)
                Spacer()
                if isCurrentIcon(icon.iconName) {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
            }
            .contentShape(Rectangle()) // Make the row tappable
            .onTapGesture {
                setAppIcon(to: icon.iconName)
            }
        }
        .navigationTitle("Choose App Icon")
    }

    func isCurrentIcon(_ iconName: String?) -> Bool {
        UIApplication.shared.alternateIconName == iconName
    }

    func setAppIcon(to iconName: String?) {
        guard UIApplication.shared.supportsAlternateIcons else {
            print("Alternate icons are not supported.")
            return
        }

        UIApplication.shared.setAlternateIconName(iconName) { error in
            if let error = error {
                print("Failed to change app icon: \(error.localizedDescription)")
            } else {
                print("App icon changed successfully!")
            }
        }
    }
}
