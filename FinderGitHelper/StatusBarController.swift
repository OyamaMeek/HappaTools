import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusBarController: NSObject, ObservableObject {
    let settingsViewModel: SettingsViewModel
    private let viewModel: MenuBarViewModel
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let popover = NSPopover()
    private let spinner = NSProgressIndicator()
    private var settingsWindow: NSWindow?
    private var subscriptions = Set<AnyCancellable>()

    override init() {
        let settings = AppSettings()
        viewModel = MenuBarViewModel(settings: settings)
        settingsViewModel = SettingsViewModel(settings: settings)
        super.init()
        NSApp.setActivationPolicy(.accessory)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "terminal", accessibilityDescription: "FinderGitHelper")
            button.toolTip = "FinderGitHelper"
            button.target = self
            button.action = #selector(togglePopover)
            spinner.style = .spinning
            spinner.controlSize = .small
            spinner.isDisplayedWhenStopped = false
            spinner.translatesAutoresizingMaskIntoConstraints = false
            button.addSubview(spinner)
            NSLayoutConstraint.activate([
                spinner.centerXAnchor.constraint(equalTo: button.centerXAnchor),
                spinner.centerYAnchor.constraint(equalTo: button.centerYAnchor),
                spinner.widthAnchor.constraint(equalToConstant: 16),
                spinner.heightAnchor.constraint(equalToConstant: 16)
            ])
        }
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: MenuBarContentView(
            viewModel: viewModel, settings: settings,
            openSettings: { [weak self] in self?.showSettings() }
        ))
        viewModel.$isLoading.sink { [weak self] loading in
            guard let self = self else { return }
            self.statusItem.button?.image = loading ? nil : NSImage(systemSymbolName: "terminal", accessibilityDescription: "FinderGitHelper")
            self.statusItem.button?.setAccessibilityLabel(loading ? "FinderGitHelper, operation in progress" : "FinderGitHelper")
            if loading { self.spinner.startAnimation(nil) } else { self.spinner.stopAnimation(nil) }
        }.store(in: &subscriptions)
        viewModel.$commitRequest.combineLatest(viewModel.$failure).sink { [weak self] request, failure in
            self?.popover.behavior = request != nil || failure != nil ? .applicationDefined : .transient
            if failure != nil {
                DispatchQueue.main.async { self?.showPopover(refresh: false) }
            }
        }.store(in: &subscriptions)
        viewModel.refreshFinderPath()
    }

    @objc private func togglePopover() {
        if popover.isShown {
            if viewModel.commitRequest == nil && viewModel.failure == nil { popover.performClose(nil) }
        } else {
            showPopover(refresh: true)
        }
    }

    private func showPopover(refresh: Bool) {
        guard let button = statusItem.button else { return }
        if refresh { viewModel.refreshFinderPath() }
        NSApp.activate(ignoringOtherApps: true)
        if !popover.isShown { popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY) }
        popover.contentViewController?.view.window?.makeKey()
    }

    private func showSettings() {
        popover.performClose(nil)
        if settingsWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(viewModel: settingsViewModel)))
            window.title = "FinderGitHelper Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
