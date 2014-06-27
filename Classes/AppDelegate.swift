//
//  AppDelegate.swift
//  LinkSame
//
//  Created by Matt Neuburg on 6/24/14.
//
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: NSDictionary?) -> Bool {
        
        ud.registerDefaults([
            Default.kSize:Sizes.Easy,
            Default.kStyle:Styles.Snacks,
            Default.kLastStage:8, // meaning 0-thru-8, so there will be nine
            Default.kScores:["Test":0] // NB didn't want to talk this way, but I was forced to "seed" the dictionary or crash
            ])
        
        self.window = UIWindow(frame:UIScreen.mainScreen().bounds)
        self.window!.rootViewController = LinkSameViewController()
        self.window!.backgroundColor = UIColor.whiteColor()
        self.window!.makeKeyAndVisible()
    
        
        return true
    }
}