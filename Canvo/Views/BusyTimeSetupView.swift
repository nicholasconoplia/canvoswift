import SwiftUI

struct BusyTimeSetupView: View {
    @Binding var busyBlocks: [BusyBlock]

    @State private var newStart = Date()
    @State private var newEnd = Date().addingTimeInterval(3600)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Busy Times")
                .font(.headline)

            List {
                ForEach(busyBlocks) { block in
                    VStack(alignment: .leading) {
                        Text("Start: \(block.start.formatted(date: .abbreviated, time: .shortened))")
                        Text("End: \(block.end.formatted(date: .abbreviated, time: .shortened))")
                    }
                }
                .onDelete { indexSet in
                    busyBlocks.remove(atOffsets: indexSet)
                }
            }

            Divider()

            Text("Add New Busy Time")
                .font(.subheadline)

            DatePicker("Start", selection: $newStart)
            DatePicker("End", selection: $newEnd)

            Button("Add Busy Block") {
                let newBlock = BusyBlock(start: newStart, end: newEnd)
                busyBlocks.append(newBlock)
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding()
    }
} 