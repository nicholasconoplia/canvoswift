import SwiftUI

struct TaskDetailView: View {
    let block: BusyBlock
    let onDelete: () -> Void
    let onUpdate: (BusyBlock) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showingEditView = false
    @State private var showingDeleteAlert = false
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE dd MMM yyyy"
        return formatter
    }()
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemBackground).edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    // Mini calendar view at the top
                    VStack(alignment: .leading, spacing: 8) {
                        Text(block.title)
                            .font(.title)
                            .bold()
                            .padding(.bottom, 4)
                        
                        Text(dateFormatter.string(from: block.start))
                            .foregroundColor(.secondary)
                        
                        Text("from \(block.start.formatted(date: .omitted, time: .shortened)) to \(block.end.formatted(date: .omitted, time: .shortened))")
                            .foregroundColor(.secondary)
                        
                        // Mini calendar preview
                        ZStack {
                            Color(.secondarySystemBackground)
                                .cornerRadius(12)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("\(Calendar.current.component(.hour, from: block.start)):00")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                HStack {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.5))
                                        .frame(height: 40)
                                        .cornerRadius(8)
                                        .overlay(
                                            Text(block.title)
                                                .font(.caption)
                                                .foregroundColor(.primary)
                                                .padding(.horizontal, 8)
                                        )
                                }
                            }
                            .padding()
                        }
                        .frame(height: 100)
                        .padding(.top)
                    }
                    .padding()
                    
                    Spacer()
                    
                    // Delete button at bottom
                    Button(action: {
                        showingDeleteAlert = true
                    }) {
                        Text("Delete Event")
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 34)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Edit") {
                    showingEditView = true
                }
            )
            .sheet(isPresented: $showingEditView) {
                TaskEditView(block: block) { updatedBlock in
                    onUpdate(updatedBlock)
                    dismiss()
                }
            }
            .alert("Delete Event", isPresented: $showingDeleteAlert) {
                Button("Delete", role: .destructive) {
                    onDelete()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete this event?")
            }
        }
    }
} 