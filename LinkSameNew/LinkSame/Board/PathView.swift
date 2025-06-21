import UIKit

class PathView: UIView {
    /// Points along the path to be drawn.
    var points = [CGPoint]() {
        didSet {
            setNeedsDisplay()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame) // caller's job to give us size
        self.isOpaque = false
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }
        guard !points.isEmpty else {
            return
        }
        context.setLineJoin(.round)
        context.setStrokeColor(red: 0.4, green: 0.4, blue: 1.0, alpha: 1.0)
        context.setLineWidth(3.0)
        context.beginPath()
        context.addLines(between: self.points)
        context.strokePath()
    }

    deinit {
        print("farewell from PathView")
    }

    func receive(_ effect: PathEffect) async {
        switch effect {
        case .illuminate(let points):
            self.points = points
        case .unilluminate:
            self.points = []
        }
    }
}

