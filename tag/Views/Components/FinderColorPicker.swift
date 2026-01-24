import SwiftUI

struct FinderColorPicker: View {
    @Binding var colorIndex: Int

    private let colors: [(Int, Color, String)] = [
        (0, .clear, "None"),
        (1, .gray, "Gray"),
        (2, .green, "Green"),
        (3, .purple, "Purple"),
        (4, .blue, "Blue"),
        (5, .yellow, "Yellow"),
        (6, .red, "Red"),
        (7, .orange, "Orange"),
    ]

    var body: some View {
        Picker("Color", selection: $colorIndex) {
            ForEach(colors, id: \.0) { index, color, name in
                HStack(spacing: 6) {
                    if index == 0 {
                        Circle()
                            .strokeBorder(Color.secondary.opacity(0.5), lineWidth: 1)
                            .frame(width: 10, height: 10)
                    } else {
                        Circle()
                            .fill(color)
                            .frame(width: 10, height: 10)
                    }
                    Text(name)
                }
                .tag(index)
            }
        }
        .labelsHidden()
    }
}

#Preview {
    @Previewable @State var colorIndex = 2

    FinderColorPicker(colorIndex: $colorIndex)
        .padding()
}
