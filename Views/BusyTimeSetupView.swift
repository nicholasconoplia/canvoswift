@MainActor
struct BusyTimeSetupView: View {
    @Binding var busyBlocks: [BusyBlock]
    @EnvironmentObject private var themeManager: ThemeManager

    @State private var newStart = Date()
    @State private var newEnd = Date().addingTimeInterval(3600)
    @State private var newTitle = ""
    
    // Calendar selection
    @State private var showingAlert = false
    @State private var alertMessage = ""

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(busyBlocks) { block in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(block.title)
                                .font(.headline)
                                .lineLimit(1)
                            Text("Start: \(block.start.formatted(date: .abbreviated, time: .shortened))")
                                .font(.subheadline)
                            Text("End: \(block.end.formatted(date: .abbreviated, time: .shortened))")
                                .font(.subheadline)
                        }
                        Spacer()
                        Button(action: {
                            if let index = busyBlocks.firstIndex(where: { $0.id == block.id }) {
                                busyBlocks.remove(at: index)
                            }
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                    .shadow(radius: 1)
                }
            }
            .padding(.vertical, 4)
        }
        .frame(maxHeight: 300)
        .background(Color(.systemGray6))
        .cornerRadius(12)

        Group {
            Text("Add New Busy Time")
                .font(.headline)

            TextField("Title", text: $newTitle)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.bottom, 4)

            DatePicker("Start", selection: $newStart)
            DatePicker("End", selection: $newEnd)

            Button("Add Busy Block") {
                if newEnd > newStart {
                    let newBlock = BusyBlock(start: newStart, end: newEnd, title: newTitle.isEmpty ? "Busy" : newTitle)
                    busyBlocks.append(newBlock)
                    
                    newStart = newEnd
                    newEnd = newEnd.addingTimeInterval(3600)
                    newTitle = ""
                } else {
                    alertMessage = "End time must be after start time"
                    showingAlert = true
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(themeManager.themeColor)
        }
    }
} 