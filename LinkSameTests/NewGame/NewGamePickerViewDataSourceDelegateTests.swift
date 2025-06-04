import UIKit
@testable import LinkSame
import Testing
import WaitWhile

@MainActor
struct NewGamePickerViewDataSourceDelegateTests {
    let subject = NewGamePickerViewDataSourceDelegate()
    let processor = MockProcessor<NewGameAction, NewGameState, NewGameEffect>()

    init() {
        subject.processor = processor
    }

    @Test("registering a picker view and presenting a state configures the picker view")
    func registerAndPresent() async throws {
        let pickerView = UIPickerView()
        subject.register(pickerView)
        #expect(pickerView.dataSource === subject)
        #expect(pickerView.delegate === subject)
        let state = NewGameState()
        await subject.present(state)
        #expect(pickerView.numberOfComponents == 1)
        #expect(pickerView.numberOfRows(inComponent: 0) == 9)
    }

    @Test("attributedTitle: returns correct value")
    func attributedTitle() throws {
        let pickerView = UIPickerView()
        var title = try #require(subject.pickerView(pickerView, attributedTitleForRow: 0, forComponent: 0))
        #expect(title.string == "1 Stage")
        var color = try #require(title.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor)
        #expect(color == .label)
        title = try #require(subject.pickerView(pickerView, attributedTitleForRow: 8, forComponent: 0))
        #expect(title.string == "9 Stages")
        color = try #require(title.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor)
        #expect(color == .label)
    }

    @Test("didSelect: sends .userSelectedPickerRow")
    func didSelect() async {
        let pickerView = UIPickerView()
        subject.pickerView(pickerView, didSelectRow: 5, inComponent: 0)
        await #while(processor.thingsReceived.isEmpty)
        #expect(processor.thingsReceived.first == .userSelectedPickerRow(5))
    }

    @Test("rowHeight: is fixed at 35")
    func rowHeight() {
        let pickerView = UIPickerView()
        let height = subject.pickerView(pickerView, rowHeightForComponent: 0)
        #expect(height == 35)
    }

}
