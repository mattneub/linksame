import UIKit
import WebKit

/// The presenter.
final class HelpViewController: UIViewController, ReceiverPresenter {
    /// Reference to the processor, set by the coordinator on creation.
    weak var processor: (any Processor<HelpAction, HelpState, Void>)?

    /// Retained instance of popover presentation delegate, set by the coordinator on creation.
    var popoverPresentationDelegate: (any UIPopoverPresentationControllerDelegate)?

    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        self.view = WKWebView()
        view.backgroundColor = .white
        Task.immediate {
            await processor?.receive(.viewDidLoad)
        }
    }

    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        (view as? WKWebView)?.isInspectable = true
        navigationItem.rightBarButtonItem = MyBarButtonItem(systemItem: .done) { [weak self] _ in
            Task.immediate {
                await self?.processor?.receive(.dismiss)
            }
        }
    }

    func present(_ state: HelpState) async {
        (view as? WKWebView)?.loadHTMLString(state.content, baseURL: nil)
    }
}
