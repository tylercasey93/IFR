public enum AdventureSaveError: Error, Equatable, Sendable {
    case newerThanApp(Int)
}
