// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Pomodoro",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "Pomodoro", targets: ["Pomodoro"]),
        .library(name: "PomodoroCore", targets: ["PomodoroCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.1")
    ],
    targets: [
        .target(
            name: "PomodoroCore"
        ),
        .executableTarget(
            name: "Pomodoro",
            dependencies: [
                "PomodoroCore",
                .product(name: "Sparkle", package: "Sparkle")
            ]
        ),
        .testTarget(
            name: "PomodoroCoreTests",
            dependencies: ["PomodoroCore"]
        ),
        .testTarget(
            name: "PomodoroTests",
            dependencies: ["Pomodoro"]
        )
    ],
    swiftLanguageModes: [.v6]
)
