

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject : AnyObject]?) -> Bool {
        
        ud.register([
            Default.size: Sizes.easy,
            Default.style: Styles.snacks,
            Default.lastStage: 8, // meaning 0-thru-8, so there will be nine
            ])
        
        self.window = UIWindow(frame:UIScreen.main().bounds)
        self.window!.rootViewController = LinkSameViewController()
        self.window!.backgroundColor = .white()
        self.window!.makeKeyAndVisible()
        
        return true
    }
}
