import Foundation

public enum Inventory {
    public static func adding(_ itemID: String, to save: AdventureSave) -> AdventureSave {
        var next = save
        next.inventory[itemID, default: 0] += 1
        return next
    }

    public static func using(_ itemID: String, from save: AdventureSave) -> AdventureSave? {
        guard let count = save.inventory[itemID], count > 0 else { return nil }
        var next = save
        if count == 1 {
            next.inventory.removeValue(forKey: itemID)
        } else {
            next.inventory[itemID] = count - 1
        }
        return next
    }

    public static func applying(_ effect: ItemEffect, to save: AdventureSave) -> AdventureSave {
        guard case .repel(let steps) = effect else { return save }
        var next = save
        next.repelStepsLeft = steps
        return next
    }
}
