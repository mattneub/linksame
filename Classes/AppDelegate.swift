

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject : AnyObject]?) -> Bool {
        
        ud.registerDefaults([
            Default.Size: Sizes.Easy,
            Default.Style: Styles.Snacks,
            Default.LastStage: 8, // meaning 0-thru-8, so there will be nine
            ])
        
        self.window = UIWindow(frame:UIScreen.mainScreen().bounds)
        self.window!.rootViewController = LinkSameViewController()
        self.window!.backgroundColor = UIColor.whiteColor()
        self.window!.makeKeyAndVisible()
        
        return true
    }
}