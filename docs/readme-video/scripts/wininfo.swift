import CoreGraphics
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as! [[String: Any]]
for w in list where (w["kCGWindowOwnerName"] as? String ?? "").contains("multi_device_preview") {
  let b = w["kCGWindowBounds"] as! [String: CGFloat]
  print(w["kCGWindowNumber"]!, Int(b["X"]!), Int(b["Y"]!), Int(b["Width"]!), Int(b["Height"]!)); break
}
