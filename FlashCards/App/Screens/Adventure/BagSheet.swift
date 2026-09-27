import SwiftUI
import IFRCore

struct BagSheet: View {
    let items: [Item]
    let inventory: [String: Int]
    let onUse: (Item) -> Void

    var body: some View {
        List(carriedItems, id: \.id) { item in
            Button("\(item.name) (\(inventory[item.id] ?? 0))") { onUse(item) }
                .accessibilityIdentifier("bagItem-\(item.id)")
        }
        .accessibilityIdentifier("bagSheet")
    }

    private var carriedItems: [Item] {
        items.filter { (inventory[$0.id] ?? 0) > 0 }
    }
}
