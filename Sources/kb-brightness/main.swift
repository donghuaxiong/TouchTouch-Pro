import Foundation
import IOKit.hid

// kb-brightness — Apple Silicon keyboard backlight via IOKit HID
// Device: vid=0x05AC, UsagePage=0xFF00, Usage=0x000F ("Keyboard Backlight")
// Feature Report ID 1: 9 bytes — [ID=1][brightness int32 LE][padding 4B]
// Range: 100 .. 14660

let args = CommandLine.arguments
guard args.count >= 2 else {
    fputs("Usage: kb-brightness [get|set <value>|available]\n", stderr)
    exit(1)
}

let command = args[1]

// MARK: - Constants

private let kReportID: UInt8 = 0x01
private let kStateReportID: UInt8 = 0x03  // on/off state
private let kMinRaw: Int32 = 100
private let kMaxRaw: Int32 = 14_660
private let cachePath = "/tmp/kb-brightness-value"

// When value is 0.0, send brightness=0 to actually turn off the backlight
// (logical minimum is 100, but 0 triggers hardware off)
private let kOffRaw: Int32 = 0

// MARK: - Helpers

func normToRaw(_ v: Float) -> Int32 {
    let clamped = min(max(v, 0), 1)
    if clamped <= 0.001 { return kOffRaw }
    return kMinRaw + Int32(clamped * Float(kMaxRaw - kMinRaw))
}

func readCache() -> Float? {
    guard let str = try? String(contentsOfFile: cachePath, encoding: .utf8),
          let val = Float(str.trimmingCharacters(in: .whitespacesAndNewlines)) else {
        return nil
    }
    return val
}

func writeCache(_ v: Float) {
    try? String(format: "%.4f\n", v).write(toFile: cachePath, atomically: true, encoding: .utf8)
}

/// Opens the HID manager, finds the KB backlight device, and calls the block.
/// Keeps the manager alive for the entire operation.
func withKBDevice<T>(_ body: (IOHIDDevice) -> T?) -> T? {
    let mgr = IOHIDManagerCreate(kCFAllocatorDefault, 0)

    let matching: [String: Any] = [
        kIOHIDDeviceUsagePageKey: 0xFF00,
        kIOHIDDeviceUsageKey:    0x000F,
        kIOHIDVendorIDKey:       0x05AC
    ]
    IOHIDManagerSetDeviceMatching(mgr, matching as CFDictionary)
    IOHIDManagerOpen(mgr, 0)

    guard let devs = IOHIDManagerCopyDevices(mgr) as NSSet?,
          let first = devs.anyObject() else {
        return nil
    }
    let device = first as! IOHIDDevice
    defer { _ = mgr } // keep mgr alive until end of scope
    return body(device)
}

// MARK: - Availability check (IOKit service, no HID manager)

func checkAvailable() -> Bool {
    let matching: [String: Any] = [
        kIOProviderClassKey: "IOHIDInterface",
        kIOHIDProductKey: "Keyboard Backlight",
        kIOHIDVendorIDKey: 1452
    ]
    var iter: io_iterator_t = 0
    let ret = IOServiceGetMatchingServices(kIOMainPortDefault, matching as CFDictionary, &iter)
    guard ret == kIOReturnSuccess else { return false }
    defer { IOObjectRelease(iter) }
    return IOIteratorNext(iter) != 0
}

// MARK: - Main

switch command {
case "available":
    print(checkAvailable() ? "yes" : "no")

case "get":
    // HID GetReport blocked by corebrightnessd; return cached value from last set.
    if let cached = readCache() {
        print(String(format: "%.4f", cached))
    } else {
        print("0.5000")
    }

case "set":
    guard args.count >= 3, let value = Float(args[2]) else {
        fputs("Usage: kb-brightness set <0.0-1.0>\n", stderr)
        exit(1)
    }
    let raw = normToRaw(value)
    let isOff = value <= 0.001

    // Retry up to 3 times (corebrightnessd may re-seize between fast invocations)
    var success = false
    for attempt in 1...3 {
        let result = withKBDevice { (dev: IOHIDDevice) -> Bool in
            let openRet = IOHIDDeviceOpen(dev, IOOptionBits(kIOHIDOptionsTypeSeizeDevice))
            guard openRet == kIOReturnSuccess else { return false }
            defer { IOHIDDeviceClose(dev, 0) }

            // 1. Set brightness (Report ID 1)
            var buf: [UInt8] = [
                kReportID,
                UInt8(raw & 0xFF),
                UInt8((raw >> 8) & 0xFF),
                UInt8((raw >> 16) & 0xFF),
                UInt8((raw >> 24) & 0xFF),
                0, 0, 0, 0
            ]

            let setRet = IOHIDDeviceSetReport(
                dev, kIOHIDReportTypeFeature, CFIndex(kReportID), &buf, buf.count
            )
            guard setRet == kIOReturnSuccess else { return false }

            // 2. Set on/off state (Report ID 3)
            //     Byte 0: Report ID (3), Byte 1: State (0=off,1=on), Bytes 2-5: usage4 (zero)
            var stateBuf: [UInt8] = [
                kStateReportID,
                isOff ? 0 : 1,
                0, 0, 0, 0
            ]
            let stateRet = IOHIDDeviceSetReport(
                dev, kIOHIDReportTypeFeature, CFIndex(kStateReportID), &stateBuf, stateBuf.count
            )

            return stateRet == kIOReturnSuccess
        }

        if result == true {
            writeCache(Float(value))
            success = true
            break
        }

        if attempt < 3 { usleep(50_000) }
    }

    if success {
        print("ok")
    } else {
        print("error")
        exit(1)
    }

default:
    fputs("Unknown command: \(command)\n", stderr)
    exit(1)
}
