//
//  SceneDelegate.swift
//  Warpinator
//
//  Created by William Millington on 2021-09-30.
//

import UIKit

import NIO
import Network

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    private let DEBUG_TAG: String = "SceneDelegate: "
    
    var window: UIWindow?
    
    var coordinator: MainCoordinator?
    

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        print(DEBUG_TAG+"scene(willConnectTo: )")
        
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        guard let windowScene = (scene as? UIWindowScene) else { return }

        let vc = UINavigationController()

        coordinator = MainCoordinator(withNavigationController: vc) //LevelCoordinator(withNavigationController: vc)

        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = vc
        window?.makeKeyAndVisible()

        coordinator?.start()
        
    }
    

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
        print(DEBUG_TAG+"sceneDidDisconnect")
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
        print(DEBUG_TAG+"sceneDidBecomeActive")
        
        coordinator?.waitForNetwork()
        .flatMap { _ -> EventLoopFuture<Void> in
            print(self.DEBUG_TAG+"We have network access")
            return self.coordinator!.startServers()
        }
        .flatMap { _ -> EventLoopFuture<Void> in

            print(self.DEBUG_TAG+"warpinator startup completed")
            return self.coordinator!.startupMdns()
        }
        .whenComplete { result in

            print(self.DEBUG_TAG+"startup result is \(result)")

            switch result {
            case .success(_): break
            case .failure(let error):

                switch error {
                    
                case NetworkMonitor.ServiceError.LOCAL_NETWORK_PERMISSION_DENIED:
                    print(self.DEBUG_TAG+"We DO NOT HAVE access to the local network!")
                    self.coordinator?.reportError(error,
                                                  withMessage: "Please enable local network access in your system settings (Settings App -> Privacy -> Local Network)")
                case NetworkError.NO_INTERNET:
                    self.coordinator?.reportError(error,
                                                  withMessage: "Please make sure wifi is turned on before restarting")
                default:
                    print(self.DEBUG_TAG+"Error starting up: \(error)")
                    self.coordinator?.reportError(error, withMessage: "Warpinator encountered an error starting up:\n\(error)")
                    return
                }
            }

            self.coordinator?.publishMdns()
        }
    }
    
    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.firefox 1
        // This may occur due to temporary interruptions (ex. an incoming phone call).
        print(DEBUG_TAG+"sceneWillResignActive")
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
        print(DEBUG_TAG+"sceneWillEnterForeground")
    }
    
    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
        print(DEBUG_TAG+"sceneDidEnterBackground")
        coordinator?.removeMdns()
        
    }


}

