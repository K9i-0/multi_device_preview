import CoreGraphics
import Foundation
// Usage: post <cmd> args. Coordinates are window content points.
let args = CommandLine.arguments
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as! [[String: Any]]
var origin = CGPoint.zero
var titlebar: CGFloat = 28
for w in list where (w["kCGWindowOwnerName"] as? String ?? "").contains("multi_device_preview") {
  let b = w["kCGWindowBounds"] as! [String: CGFloat]
  origin = CGPoint(x: b["X"]!, y: b["Y"]!)
  break
}
func pt(_ x: String, _ y: String) -> CGPoint { CGPoint(x: origin.x + CGFloat(Double(x)!), y: origin.y + titlebar + CGFloat(Double(y)!)) }
let src = CGEventSource(stateID: .hidSystemState)
func mouse(_ type: CGEventType, _ p: CGPoint) { CGEvent(mouseEventSource: src, mouseType: type, mouseCursorPosition: p, mouseButton: .left)!.post(tap: .cghidEventTap); usleep(16000) }
switch args[1] {
case "info": print("origin \(origin)")
case "click":
  let p = pt(args[2], args[3]); mouse(.mouseMoved, p); mouse(.leftMouseDown, p); usleep(60000); mouse(.leftMouseUp, p)
case "drag":
  let p = pt(args[2], args[3]); let dy = CGFloat(Double(args[4])!)
  mouse(.mouseMoved, p); mouse(.leftMouseDown, p)
  for i in 1...20 { mouse(.leftMouseDragged, CGPoint(x: p.x, y: p.y + dy * CGFloat(i) / 20)) }
  mouse(.leftMouseUp, CGPoint(x: p.x, y: p.y + dy))
case "wheel":
  let p = pt(args[2], args[3]); mouse(.mouseMoved, p)
  for _ in 0..<10 { CGEvent(scrollWheelEvent2Source: src, units: .pixel, wheelCount: 1, wheel1: Int32(args[4])!, wheel2: 0, wheel3: 0)!.post(tap: .cghidEventTap); usleep(20000) }
case "type":
  for ch in args[2].utf16 { let d = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: true)!; var c = ch; d.keyboardSetUnicodeString(stringLength: 1, unicodeString: &c); d.post(tap: .cghidEventTap); let u = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: false)!; u.keyboardSetUnicodeString(stringLength: 1, unicodeString: &c); u.post(tap: .cghidEventTap); usleep(30000) }
case "enter":
  CGEvent(keyboardEventSource: src, virtualKey: 36, keyDown: true)!.post(tap: .cghidEventTap); usleep(30000)
  CGEvent(keyboardEventSource: src, virtualKey: 36, keyDown: false)!.post(tap: .cghidEventTap)
case "keys":
  for code in args[2].split(separator: ",").map({ UInt16($0)! }) {
    CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: true)!.post(tap: .cghidEventTap); usleep(30000)
    CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: false)!.post(tap: .cghidEventTap); usleep(60000)
  }
case "trackpad":
  let p = pt(args[2], args[3]); mouse(.mouseMoved, p)
  let dy = Int32(args[4])!
  for i in 0..<12 {
    let e = CGEvent(scrollWheelEvent2Source: src, units: .pixel, wheelCount: 1, wheel1: i == 0 ? 0 : dy, wheel2: 0, wheel3: 0)!
    e.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
    e.setIntegerValueField(.scrollWheelEventScrollPhase, value: i == 0 ? 1 : 2)
    e.post(tap: .cghidEventTap); usleep(16000)
  }
  let end = CGEvent(scrollWheelEvent2Source: src, units: .pixel, wheelCount: 1, wheel1: 0, wheel2: 0, wheel3: 0)!
  end.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
  end.setIntegerValueField(.scrollWheelEventScrollPhase, value: 4)
  end.post(tap: .cghidEventTap)
default: print("?")
}
