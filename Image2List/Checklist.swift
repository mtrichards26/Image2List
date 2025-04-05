//
//  ChecklistItem.swift
//  Image2List
//
//  Created by Matt Richards on 4/5/25.
//
import SwiftUI

struct ChecklistItem: Identifiable, Comparable {
    let id = UUID()
    var text: String
    var isChecked: Bool = false
    let originalIndex: Int
    
    static func < (lhs: ChecklistItem, rhs: ChecklistItem) -> Bool {
        if lhs.isChecked == rhs.isChecked {
            return lhs.originalIndex < rhs.originalIndex
        }
        return !lhs.isChecked
    }
}

struct ChecklistItemRow: View {
    @Binding var item: ChecklistItem
    let onCheck: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundColor(item.isChecked ? Color(red: 0.4, green: 0.7, blue: 0.4) : Color(red: 0.6, green: 0.6, blue: 0.6))
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        item.isChecked.toggle()
                        onCheck()
                    }
                }
            
            Text(item.text)
                .font(.body)
                .foregroundColor(item.isChecked ? Color(red: 0.6, green: 0.6, blue: 0.6) : Color(red: 0.2, green: 0.2, blue: 0.2))
                .strikethrough(item.isChecked)
            
            Spacer()
            
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 16))
                .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.6))
                .padding(.trailing, 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(red: 0.95, green: 0.97, blue: 0.95))
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                withAnimation {
                    onDelete()
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .tint(Color(red: 0.7, green: 0.3, blue: 0.3))
        }
    }
}
