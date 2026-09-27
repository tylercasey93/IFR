import Foundation

public enum Camera {
    public static func origin(
        following player: GridPoint,
        mapWidth: Int,
        mapHeight: Int,
        viewportWidth: Int = 15,
        viewportHeight: Int = 10
    ) -> GridPoint {
        GridPoint(
            x: clamped(player.x - viewportWidth / 2, extent: mapWidth, viewport: viewportWidth),
            y: clamped(player.y - viewportHeight / 2, extent: mapHeight, viewport: viewportHeight)
        )
    }

    private static func clamped(_ value: Int, extent: Int, viewport: Int) -> Int {
        min(max(value, 0), max(extent - viewport, 0))
    }
}
