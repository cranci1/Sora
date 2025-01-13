import SwiftUI

struct IconSwitcherView: View {
    var body: some View {
        VStack {
            Text("Choose an App Icon")
                .font(.headline)
                .padding()

            Button("Set Default Icon") {
                UIApplication.shared.setAlternateIconName(nil) { error in
                    if let error = error {
                        print("Error switching to default icon: \(error.localizedDescription)")
                    } else {
                        print("Switched to default icon")
                    }
                }
            }
            .padding()

            Button("Set Alternate Icon 1") {
                UIApplication.shared.setAlternateIconName("AlternateIcon1") { error in
                    if let error = error {
                        print("Error switching to AlternateIcon1: \(error.localizedDescription)")
                    } else {
                        print("Switched to AlternateIcon1")
                    }
                }
            }
            .padding()

            Button("Set Alternate Icon 2") {
                UIApplication.shared.setAlternateIconName("AlternateIcon2") { error in
                    if let error = error {
                        print("Error switching to AlternateIcon2: \(error.localizedDescription)")
                    } else {
                        print("Switched to AlternateIcon2")
                    }
                }
            }
            .padding()
        }
        .navigationTitle("App Icon Switcher")
    }
}

struct IconSwitcherView_Previews: PreviewProvider {
    static var previews: some View {
        IconSwitcherView()
    }
}
