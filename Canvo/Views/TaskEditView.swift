import SwiftUI

struct TaskEditView: View {
    let block: BusyBlock
    let onSave: (BusyBlock) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var title: String
    @State private var startDate: Date
    @State private var endDate: Date
    
    init(block: BusyBlock, onSave: @escaping (BusyBlock) -> Void) {
        self.block = block
        self.onSave = onSave
        _title = State(initialValue: block.title)
        _startDate = State(initialValue: block.start)
        _endDate = State(initialValue: block.end)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Title", text: $title)
                }
                
                Section {
                    DatePicker("Starts", selection: $startDate)
                    DatePicker("Ends", selection: $endDate)
                }
            }
            .navigationTitle("Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Done") {
                    let updatedBlock = BusyBlock(
                        id: block.id,
                        start: startDate,
                        end: endDate,
                        title: title,
                        location: block.location
                    )
                    onSave(updatedBlock)
                }
                .disabled(title.isEmpty || endDate <= startDate)
            )
        }
    }
} 