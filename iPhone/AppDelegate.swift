import UIKit
import SwiftUI

@main @MainActor final class RemoteAppDelegate: UIResponder, UIApplicationDelegate {
    let client = RemoteClient()
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let external = connectingSceneSession.role == .windowExternalDisplayNonInteractive
        let configuration = UISceneConfiguration(name: external ? "Glasses" : "Phone", sessionRole: connectingSceneSession.role)
        configuration.delegateClass = external ? GlassesSceneDelegate.self : PhoneSceneDelegate.self
        return configuration
    }
}
@MainActor final class PhoneSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene, let app = UIApplication.shared.delegate as? RemoteAppDelegate else { return }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIHostingController(rootView: RemoteClientView(client: app.client))
        window.makeKeyAndVisible(); self.window = window
    }
    func sceneDidEnterBackground(_ scene: UIScene) {
        // iOS may suspend networking in the background. Reconnect explicitly on return.
        (UIApplication.shared.delegate as? RemoteAppDelegate)?.client.disconnect()
    }
}
@MainActor final class GlassesSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var video: RemoteVideoView?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene, let app = UIApplication.shared.delegate as? RemoteAppDelegate else { return }
        let window = UIWindow(windowScene: scene)
        let controller = UIViewController(); controller.view.backgroundColor = .black
        let video = RemoteVideoView(); video.translatesAutoresizingMaskIntoConstraints = false
        controller.view.addSubview(video)
        NSLayoutConstraint.activate([video.leadingAnchor.constraint(equalTo: controller.view.leadingAnchor), video.trailingAnchor.constraint(equalTo: controller.view.trailingAnchor),
                                     video.topAnchor.constraint(equalTo: controller.view.topAnchor), video.bottomAnchor.constraint(equalTo: controller.view.bottomAnchor)])
        window.rootViewController = controller; window.isHidden = false
        self.window = window; self.video = video
        app.client.register(video); app.client.externalConnected = true
    }
    func sceneDidDisconnect(_ scene: UIScene) {
        if let app = UIApplication.shared.delegate as? RemoteAppDelegate {
            if let video { app.client.unregister(video) }
            app.client.externalConnected = false
        }
        video = nil; window = nil
    }
}
