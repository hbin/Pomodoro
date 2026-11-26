import ApplicationServices
import Foundation

let args = CommandLine.arguments

guard args.count >= 3, let pid = pid_t(args[1]) else {
    fputs("usage: MotionAX <pid> geometry|dial|press <desc|help|value> <substring>\n", stderr)
    exit(2)
}

guard AXIsProcessTrusted() else {
    fputs("Accessibility permission is required\n", stderr)
    exit(2)
}

let app = AXUIElementCreateApplication(pid)

func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else {
        return nil
    }
    return value
}

func stringAttribute(_ element: AXUIElement, _ name: String) -> String {
    guard let value = attribute(element, name) else { return "" }
    return String(describing: value)
}

func children(_ element: AXUIElement) -> [AXUIElement] {
    guard let list = attribute(element, kAXChildrenAttribute as String) as? [AXUIElement] else {
        return []
    }
    return list
}

@discardableResult
func walk(_ element: AXUIElement, _ visit: (AXUIElement) -> Bool) -> Bool {
    if visit(element) { return true }
    for child in children(element) where walk(child, visit) {
        return true
    }
    return false
}

func stringField(_ element: AXUIElement, _ field: String) -> String {
    switch field {
    case "desc":
        return stringAttribute(element, kAXDescriptionAttribute as String)
    case "help":
        return stringAttribute(element, kAXHelpAttribute as String)
    case "value":
        return stringAttribute(element, kAXValueAttribute as String)
    default:
        return ""
    }
}

switch args[2] {
case "geometry":
    var window: AXUIElement?
    walk(app) { element in
        guard stringAttribute(element, kAXRoleAttribute as String) == "AXWindow" else {
            return false
        }
        window = element
        return true
    }
    guard let window,
          let positionAttribute = attribute(window, kAXPositionAttribute as String),
          let sizeAttribute = attribute(window, kAXSizeAttribute as String)
    else {
        fputs("window not found\n", stderr)
        exit(1)
    }
    let positionValue = positionAttribute as! AXValue
    let sizeValue = sizeAttribute as! AXValue
    var position = CGPoint.zero
    var size = CGSize.zero
    guard AXValueGetValue(positionValue, .cgPoint, &position),
          AXValueGetValue(sizeValue, .cgSize, &size)
    else {
        fputs("window geometry unavailable\n", stderr)
        exit(1)
    }
    print("\(position.x) \(position.y) \(size.width) \(size.height)")

case "dial":
    var dial: AXUIElement?
    walk(app) { element in
        let description = stringAttribute(element, kAXDescriptionAttribute as String)
        let valueDescription = stringAttribute(element, kAXValueDescriptionAttribute as String)
        guard description.contains("timer"), !valueDescription.isEmpty else {
            return false
        }
        dial = element
        return true
    }
    guard let dial else {
        fputs("timer dial not found\n", stderr)
        exit(1)
    }
    print(
        "desc=\(stringAttribute(dial, kAXDescriptionAttribute as String))"
            + "\tvalueDesc=\(stringAttribute(dial, kAXValueDescriptionAttribute as String))"
    )

case "press":
    guard args.count >= 5 else { exit(2) }
    let field = args[3]
    let needle = args[4]
    var button: AXUIElement?
    walk(app) { element in
        guard stringAttribute(element, kAXRoleAttribute as String) == "AXButton" else {
            return false
        }
        let haystack = stringField(element, field)
        guard !haystack.isEmpty, haystack.contains(needle) else { return false }
        button = element
        return true
    }
    guard let button else {
        fputs("button not found: \(field) contains \(needle)\n", stderr)
        exit(1)
    }
    let error = AXUIElementPerformAction(button, kAXPressAction as CFString)
    guard error == .success else {
        fputs("button press failed: \(error.rawValue)\n", stderr)
        exit(1)
    }

default:
    fputs("usage: MotionAX <pid> geometry|dial|press <desc|help|value> <substring>\n", stderr)
    exit(2)
}
