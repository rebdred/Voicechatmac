import SwiftUI
import AppKit

@main
struct VoiceChatApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .background(Color.clear)
                .onAppear {
                    setupFloatingWindow()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 300, height: 400)  // Match the ContentView size
    }
    
    private func setupFloatingWindow() {
        if let window = NSApplication.shared.windows.first {
            // Make window floating (always on top)
            window.level = .floating
            
            // Make window non-activating (doesn't steal focus)
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            
            // Position window in top-right corner
            if let screen = NSScreen.main {
                let screenFrame = screen.visibleFrame
                let windowFrame = window.frame
                let newOrigin = NSPoint(
                    x: screenFrame.maxX - windowFrame.width - 20,
                    y: screenFrame.maxY - windowFrame.height - 20
                )
                window.setFrameOrigin(newOrigin)
            }
            
            // Make window background solid (not transparent)
            window.backgroundColor = NSColor.windowBackgroundColor
            window.isOpaque = true
            window.hasShadow = true
            
            // Prevent window from being closed by user
            window.isMovableByWindowBackground = true
        }
    }
} 