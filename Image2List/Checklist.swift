//
//  ChecklistItem.swift
//  Image2List
//
//  Created by Matt Richards on 4/5/25.
//
import SwiftUI

/// Title-case for list display: first letter of each word capitalized, rest lowercased (e.g. "whole milk" → "Whole Milk", "2 apples" → "2 Apples").
func titleCasedForList(_ string: String) -> String {
    string.trimmingCharacters(in: .whitespacesAndNewlines)
        .split(separator: " ")
        .map { word in
            let s = String(word)
            guard !s.isEmpty else { return s }
            return s.prefix(1).uppercased() + s.dropFirst().lowercased()
        }
        .joined(separator: " ")
}

/// Store section for grouping grocery items. Raw values match AI response format.
enum StoreSection: String, CaseIterable, Codable {
    case deli = "Deli"
    case bakery = "Bakery"
    case meat = "Meat"
    case beverages = "Beverages"
    case produce = "Produce"
    case snacks = "Snacks"
    case personalHousehold = "Personal & Household"
    case pantry = "Pantry"
    case international = "International"
    case dairyEggs = "Dairy/Eggs"
    case frozen = "Frozen"
    case other = "Other"
    
    var displayName: String { rawValue }
    
    /// Order used for sorting the list (store layout).
    var sortOrder: Int {
        switch self {
        case .deli: return 0
        case .bakery: return 1
        case .meat: return 2
        case .beverages: return 3
        case .produce: return 4
        case .snacks: return 5
        case .personalHousehold: return 6
        case .pantry: return 7
        case .international: return 8
        case .dairyEggs: return 9
        case .frozen: return 10
        case .other: return 11
        }
    }
    
    /// Description for the AI prompt (raw value + hint). Used when building the extraction prompt.
    var promptDescription: String {
        switch self {
        case .deli: return "Deli - Fresh deli section for sliced meats and cheeses"
        case .bakery: return "Bakery - Bread, rolls, pastries, cakes"
        case .meat: return "Meat - Meat, Fish, Poultry"
        case .beverages: return "Beverages"
        case .produce: return "Produce - Fresh fruits and vegetables"
        case .snacks: return "Snacks - Chips, candy, nuts, granola bars, etc."
        case .personalHousehold: return "Personal & Household"
        case .pantry: return "Pantry - Dry goods (cereal, baking, seasoning, oil, vinegar, sauces, jelly, etc.)"
        case .international: return "International - International foods, ethnic ingredients"
        case .dairyEggs: return "Dairy/Eggs"
        case .frozen: return "Frozen - Frozen foods"
        case .other: return "Other - Doesn't fit into the above or unknown"
        }
    }
    
    /// All sections in store order (for prompt and display).
    static var orderedForPrompt: [StoreSection] {
        allCases.sorted { $0.sortOrder < $1.sortOrder }
    }
}

struct ChecklistItem: Identifiable, Comparable, Codable {
    let id: UUID
    var text: String
    var isChecked: Bool = false
    let originalIndex: Int
    var section: StoreSection
    
    init(id: UUID = UUID(), text: String, isChecked: Bool = false, originalIndex: Int, section: StoreSection = .other) {
        self.id = id
        self.text = text
        self.isChecked = isChecked
        self.originalIndex = originalIndex
        self.section = section
    }
    
    enum CodingKeys: String, CodingKey {
        case id, text, isChecked, originalIndex, section
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        text = try c.decode(String.self, forKey: .text)
        isChecked = try c.decodeIfPresent(Bool.self, forKey: .isChecked) ?? false
        originalIndex = try c.decode(Int.self, forKey: .originalIndex)
        section = try c.decodeIfPresent(StoreSection.self, forKey: .section) ?? .other
    }
    
    static func < (lhs: ChecklistItem, rhs: ChecklistItem) -> Bool {
        if lhs.isChecked != rhs.isChecked {
            return !lhs.isChecked
        }
        if lhs.section.sortOrder != rhs.section.sortOrder {
            return lhs.section.sortOrder < rhs.section.sortOrder
        }
        return lhs.originalIndex < rhs.originalIndex
    }
}

struct ChecklistItemRow: View {
    @Binding var item: ChecklistItem
    let onCheck: () -> Void
    let onDelete: () -> Void
    let onBeginEdit: () -> Void
    
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
            
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.text)
                        .font(.body)
                        .foregroundColor(item.isChecked ? Color(red: 0.6, green: 0.6, blue: 0.6) : Color(red: 0.2, green: 0.2, blue: 0.2))
                        .strikethrough(item.isChecked)
                    if item.section != .other {
                        Text(item.section.displayName)
                            .font(.caption)
                            .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.5))
                    }
                }
                
                Spacer()
                
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 16))
                    .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.6))
                    .padding(.trailing, 4)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onBeginEdit()
            }
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
