import Foundation

// kb-brightness CLI tool using CoreBrightness.framework (private API)
// Usage:
//   kb-brightness available  → prints "yes" or "no"
//   kb-brightness get        → prints current value (0.0-1.0)
//   kb-brightness set <val>  → sets keyboard backlight (0.0-1.0)

let args = CommandLine.arguments
guard args.count >= 2 else {
    fputs("Usage: kb-brightness [get|set <value>|available]\n", stderr)
    exit(1)
}

let command = args[1]

// Load CoreBrightness.framework
let coreBrightnessPath = "/System/Library/PrivateFrameworks/CoreBrightness.framework"
guard let bundle = Bundle(path: coreBrightnessPath), bundle.load() else {
    print("error")
    exit(1)
}

guard let kbClientClass = NSClassFromString("KeyboardBrightnessClient") as? NSObject.Type else {
    print("error")
    exit(1)
}

nonisolated(unsafe) let client = kbClientClass.init()

// Get keyboard ID from copyKeyboardBacklightIDs
func getKeyboardID() -> UInt64? {
    let selector = NSSelectorFromString("copyKeyboardBacklightIDs")
    guard client.responds(to: selector),
          let ids = client.perform(selector)?.takeUnretainedValue() as? [NSNumber],
          let firstID = ids.first else {
        return nil
    }
    return firstID.uint64Value
}

func getBrightness(keyboardID: UInt64) -> Float? {
    let selector = NSSelectorFromString("brightnessForKeyboard:")
    guard client.responds(to: selector) else { return nil }
    typealias GetFunc = @convention(c) (NSObject, Selector, UInt64) -> Float
    let impl = unsafeBitCast(client.method(for: selector), to: GetFunc.self)
    return impl(client, selector, keyboardID)
}

func setBrightness(_ value: Float, keyboardID: UInt64) -> Bool {
    let selector = NSSelectorFromString("setBrightness:forKeyboard:")
    guard client.responds(to: selector) else { return false }
    typealias SetFunc = @convention(c) (NSObject, Selector, Float, UInt64) -> Bool
    let impl = unsafeBitCast(client.method(for: selector), to: SetFunc.self)
    return impl(client, selector, value, keyboardID)
}

switch command {
case "available":
    print(getKeyboardID() != nil ? "yes" : "no")

case "get":
    guard let kbID = getKeyboardID(),
          let val = getBrightness(keyboardID: kbID) else {
        print("error"); exit(1)
    }
    print(String(format: "%.4f", val))

case "set":
    guard args.count >= 3, let value = Float(args[2]) else {
        fputs("Usage: kb-brightness set <0.0-1.0>\n", stderr); exit(1)
    }
    guard let kbID = getKeyboardID() else {
        print("error: no keyboard"); exit(1)
    }
    let clamped = min(max(value, 0), 1)
    if setBrightness(clamped, keyboardID: kbID) {
        print("ok")
    } else {
        print("error"); exit(1)
    }

default:
    fputs("Unknown command: \(command)\n", stderr); exit(1)
}
