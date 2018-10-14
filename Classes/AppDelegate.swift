

import UIKit

// utility

func delay(_ delay:Double, closure:@escaping ()->()) {
    let when = DispatchTime.now() + delay
    DispatchQueue.main.asyncAfter(deadline: when, execute: closure)
}

extension RangeReplaceableCollection where Iterator.Element : Equatable {
    mutating func remove(object:Self.Iterator.Element) {
        if let found = self.firstIndex(of: object) {
            self.remove(at: found)
        }
    }
}

// space savers

let ud = UserDefaults.standard

let nc = NotificationCenter.default

extension UIApplication {
    // false means no user interaction, true means turn it back on
    static func ui(_ yn:Bool) {
        if !yn {
            UIApplication.shared.beginIgnoringInteractionEvents()
        } else {
            UIApplication.shared.endIgnoringInteractionEvents()
        }
    }
}

// operators

infix operator >>> : RangeFormationPrecedence
func >>><Bound>(maximum: Bound, minimum: Bound)
    -> ReversedCollection<Range<Bound>>
    where Bound : Strideable {
        return (minimum..<maximum).reversed()
}


infix operator <<< : RangeFormationPrecedence
func <<<<Bound>(minimum: Bound, maximum: Bound)
    -> Range<Bound>
    where Bound : Strideable {
        return (minimum..<maximum)
}

// determination of hardware environment

var onPhone : Bool {
    return UIScreen.main.traitCollection.userInterfaceIdiom == .phone
}

var on3xScreen : Bool {
    return UIScreen.main.traitCollection.displayScale > 2.5
}

// keys used in user defaults, determination of board size, game configurations, tile pictures

struct Default {
    static let size = "Size"
    static let style = "Style"
    static let lastStage = "Stages"
    static let scores = "Scoresv2"
    static let boardData = "boardDatav2"
    static let gameEnded = "gameEnded"
}

struct Sizes {
    static let easy = "Easy"
    static let normal = "Normal"
    static let hard = "Hard"
    static func sizes () -> [String] {
        return [easy, normal, hard]
    }
    private static var easySize : (Int,Int) {
        var result : (Int,Int) = onPhone ? (10,6) : (12,7)
        if on3xScreen { result = (12,7) }
        return result
    }
    static func boardSize (_ s:String) -> (Int,Int) {
        let d = [
            easy:self.easySize,
            normal:(14,8),
            hard:(16,9)
        ]
        return d[s]!
    }
}

struct Styles {
    static let animals = "Animals"
    static let snacks = "Snacks"
    static func styles () -> [String] {
        return [animals, snacks]
    }
    static func pieces (_ s:String) -> (Int,Int) {
        let d = [
            animals:(11,110),
            snacks:(21,210)
        ]
        return d[s]!
    }
}


// =========================================


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]?) -> Bool {
        
        ud.register(defaults: [
            Default.size: Sizes.easy,
            Default.style: Styles.snacks,
            Default.lastStage: 8, // meaning 0-thru-8, so there will be nine
        ])
        
        self.window = self.window ?? UIWindow()
        self.window!.rootViewController = LinkSameViewController()
        self.window!.backgroundColor = .white
        self.window!.makeKeyAndVisible()
        
        return true
    }
}
