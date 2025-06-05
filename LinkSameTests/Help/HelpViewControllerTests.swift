import UIKit
import WebKit
@testable import LinkSame
import Testing
import WaitWhile

@MainActor
struct HelpViewControllerTests {
    let subject = HelpViewController()
    let processor = MockProcessor<HelpAction, HelpState, Void>()
    let popoverDelegate = MockPopoverPresentationDelegate()

    init() {
        subject.processor = processor
        subject.popoverPresentationDelegate = popoverDelegate
    }

    @Test("view is a web view; loading view sends viewDidLoad to processor")
    func loadView() async {
        subject.loadViewIfNeeded()
        #expect(subject.view is WKWebView)
        #expect(subject.view.backgroundColor == .white)
        await #while(processor.thingsReceived.isEmpty)
        #expect(processor.thingsReceived.last == .viewDidLoad)
    }

    @Test("viewIsAppearing: sets up navigation item, navigation controller's nav bar")
    func viewIsAppearing() async throws {
        let navigationController = UINavigationController(rootViewController: subject)
        subject.viewIsAppearing(false)
        let navigationBar = navigationController.navigationBar
        #expect(navigationBar.scrollEdgeAppearance == navigationBar.standardAppearance)
        #expect(navigationBar.compactScrollEdgeAppearance == navigationBar.compactAppearance)
        let barButtonItem = try #require(subject.navigationItem.rightBarButtonItem as? MyBarButtonItem)
        #expect(barButtonItem.value(forKey: "systemItem") as? Int == 0)
        barButtonItem.actionHandler?(UIAction(title: "", handler: { _ in }))
        await #while(processor.thingsReceived.last != .dismiss)
        #expect(processor.thingsReceived.last == .dismiss)
    }

    @Test("present: loads state content into web view")
    func present() async throws {
        subject.loadViewIfNeeded()
        await subject.present(HelpState(content: "testing"))
        let webView = try #require(subject.view as? WKWebView)
        await #while(webView.isLoading)
        let result = try await webView.find("testing")
        #expect(result.matchFound)
    }
}
