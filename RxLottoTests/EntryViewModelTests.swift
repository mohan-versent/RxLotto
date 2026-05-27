import XCTest
import RxSwift
import RxTest
@testable import RxLotto

// These tests use RxTest's TestScheduler — a virtual clock that lets us
// control time in tests (e.g. simulate debounce without actually waiting 300ms).
//
final class EntryViewModelTests: XCTestCase {

    var viewModel: EntryViewModel!
    var disposeBag: DisposeBag!

    override func setUp() {
        super.setUp()
        viewModel = EntryViewModel()
        disposeBag = DisposeBag()
    }

    // MARK: - Validation Tests

    func testValidEntry() {
        XCTAssertNil(EntryViewModel.validate([7, 14, 22, 33, 41, 45]))
    }

    func testTooFewNumbers() {
        let error = EntryViewModel.validate([1, 2, 3])
        XCTAssertNotNil(error)
        XCTAssertTrue(error!.contains("6"))
    }

    func testTooManyNumbers() {
        let error = EntryViewModel.validate([1, 2, 3, 4, 5, 6, 7])
        XCTAssertNotNil(error)
    }

    func testNumberOutOfRange() {
        let error = EntryViewModel.validate([0, 14, 22, 33, 41, 45])
        XCTAssertNotNil(error)
        XCTAssertTrue(error!.contains("1 and 45"))
    }

    func testNumberAboveMax() {
        let error = EntryViewModel.validate([7, 14, 22, 33, 41, 46])
        XCTAssertNotNil(error)
    }

    func testDuplicateNumbers() {
        let error = EntryViewModel.validate([7, 7, 22, 33, 41, 45])
        XCTAssertNotNil(error)
        XCTAssertTrue(error!.contains("unique"))
    }

    // MARK: - LottoEntry Match Tests

    func testMatchCount() {
        let entry = LottoEntry(numbers: [7, 14, 22, 33, 41, 45])
        let draw = DrawResult(winningNumbers: [7, 14, 22, 99, 88, 77])
        XCTAssertEqual(entry.matchCount(against: draw), 3)
    }

    func testNoMatches() {
        let entry = LottoEntry(numbers: [1, 2, 3, 4, 5, 6])
        let draw = DrawResult(winningNumbers: [7, 8, 9, 10, 11, 12])
        XCTAssertEqual(entry.matchCount(against: draw), 0)
    }

    func testFullMatch() {
        let numbers = [7, 14, 22, 33, 41, 45]
        let entry = LottoEntry(numbers: numbers)
        let draw = DrawResult(winningNumbers: numbers)
        XCTAssertEqual(entry.matchCount(against: draw), 6)
    }

    // MARK: - Observable Output Tests

    func testIsValidEmitsFalseInitially() {
        let expectation = XCTestExpectation(description: "isValid starts false")
        viewModel.isValid
            .take(1)
            .subscribe(onNext: { isValid in
                XCTAssertFalse(isValid)
                expectation.fulfill()
            })
            .disposed(by: disposeBag)
        wait(for: [expectation], timeout: 1.0)
    }

    func testIsValidEmitsTrueForValidInput() {
        let expectation = XCTestExpectation(description: "isValid becomes true")
        viewModel.isValid
            .skip(1)  // skip the initial false
            .take(1)
            .subscribe(onNext: { isValid in
                XCTAssertTrue(isValid)
                expectation.fulfill()
            })
            .disposed(by: disposeBag)

        viewModel.entryText.onNext("7, 14, 22, 33, 41, 45")
        wait(for: [expectation], timeout: 1.0)
    }

    func testValidationMessageContainsErrorForInvalidInput() {
        let expectation = XCTestExpectation(description: "validation message shows error")
        viewModel.validationMessage
            .skip(1)
            .take(1)
            .subscribe(onNext: { message in
                XCTAssertTrue(message.contains("⚠️"))
                expectation.fulfill()
            })
            .disposed(by: disposeBag)

        viewModel.entryText.onNext("1, 2, 3")
        wait(for: [expectation], timeout: 1.0)
    }
}
