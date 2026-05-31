import AppKit

final class StatusItem: NSObject {
    let item: NSStatusItem
    var onToggle: (() -> Void)?
    var onQuit: (() -> Void)?

    override init() {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        item.button?.title = "🎹"
        item.button?.toolTip = "OnScreen Keyboard"

        let menu = NSMenu()
        menu.addItem(makeItem("Toggle Keyboard   ⌘K", #selector(handleToggle)))
        menu.addItem(.separator())
        menu.addItem(makeItem("Quit OnScreen Keyboard", #selector(handleQuit)))
        item.menu = menu
    }

    private func makeItem(_ title: String, _ action: Selector) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: "")
        i.target = self
        return i
    }

    @objc private func handleToggle() { onToggle?() }
    @objc private func handleQuit() { onQuit?() }
}
