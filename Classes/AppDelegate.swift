

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject : AnyObject]?) -> Bool {
        
        ud.registerDefaults([
            Default.Size: Sizes.Easy,
            Default.Style: Styles.Snacks,
            Default.LastStage: 8, // meaning 0-thru-8, so there will be nine
            Default.Scores: ["Test":0] // NB didn't want to talk this way, but I was forced to "seed" the dictionary or crash
            ])
        
        self.window = UIWindow(frame:UIScreen.mainScreen().bounds)
        self.window!.rootViewController = LinkSameViewController()
        self.window!.backgroundColor = UIColor.whiteColor()
        self.window!.makeKeyAndVisible()
        
        return true
    }
}