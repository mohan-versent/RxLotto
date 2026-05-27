import Foundation
import RxSwift
import RxCocoa

// EntryViewModel: the brain of the screen.
// It takes raw user input (Strings) and transforms them into UI-ready outputs.
//
// MVVM + RxSwift pattern:
//   ViewController  →  sends raw events into ViewModel inputs
//   ViewModel       →  transforms, validates, exposes Observable outputs
//   ViewController  →  binds outputs to UI elements
//
class EntryViewModel {

    // MARK: - Inputs
    // BehaviorSubject = an Observable that holds a current value AND emits it to new subscribers.
    // C# equivalent: a reactive property / IObservable<string> backed by a BehaviorSubject.
    let entryText = BehaviorSubject<String>(value: "")

    // PublishSubject = emits only NEW events — no stored value.
    // C# equivalent: Subject<Unit> — used for button taps / one-shot triggers.
    let submitTapped = PublishSubject<Void>()

    // MARK: - Outputs (what the ViewController binds to)
    let validationMessage: Observable<String>
    let isValid: Observable<Bool>
    let isLoading: Observable<Bool>
    let drawResult: Observable<DrawResult?>

    // MARK: - Private
    // DisposeBag = the RxSwift memory manager.
    // When this ViewModel is deallocated, the bag disposes all subscriptions automatically.
    // C# equivalent: CompositeDisposable.
    private let disposeBag = DisposeBag()
    private let drawService: DrawService

    init(drawService: DrawService = DrawService()) {
        self.drawService = drawService

        // MARK: Parse & validate the entry text
        //
        // The chain below reads like a pipeline (think LINQ in C#):
        //   entryText stream
        //     → debounce 300ms     (wait for user to stop typing)
        //     → distinctUntilChanged (skip if value didn't change)
        //     → map to [Int]       (parse "7, 14, 22" → [7, 14, 22])
        //     → share              (one subscription feeds both isValid and validationMessage)
        //
        let parsed: Observable<[Int]> = entryText
            .debounce(.milliseconds(300), scheduler: MainScheduler.instance)
            .distinctUntilChanged()
            .filter { !$0.isEmpty }  // don't process empty input — lets startWith message stay visible
            .map { text in
                // Split by comma or space, parse each token to Int, drop nils
                text.components(separatedBy: CharacterSet(charactersIn: ", "))
                    .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            }
            .share(replay: 1) // share = one upstream, multiple downstream subscribers

        // MARK: isValid
        // map transforms each [Int] emission into a Bool
        isValid = parsed
            .map { EntryViewModel.validate($0) == nil }
            .startWith(false) // start as invalid before user types anything

        // MARK: validationMessage
        // map transforms each [Int] emission into a human-readable String
        validationMessage = parsed
            .map { numbers -> String in
                if let error = EntryViewModel.validate(numbers) {
                    return "⚠️ \(error)"
                }
                let sorted = numbers.sorted().map(String.init).joined(separator: "  ")
                return "✅ Entry ready: \(sorted)"
            }
            .startWith("Enter 6 numbers (1–45), separated by commas")

        // MARK: drawResult + isLoading
        //
        // withLatestFrom = "when submitTapped fires, grab the latest value from entryText"
        // flatMapLatest = "cancel any previous API call, start a new one"
        //   (important for search boxes — if user submits again, old request is cancelled)
        //
        let isLoadingRelay = BehaviorSubject<Bool>(value: false)
        isLoading = isLoadingRelay.asObservable()

        drawResult = submitTapped
            .withLatestFrom(parsed)                  // grab latest parsed numbers on tap
            .filter { EntryViewModel.validate($0) == nil } // only proceed if valid
            .do(onNext: { _ in isLoadingRelay.onNext(true) })  // show spinner
            .flatMapLatest { [weak drawService] _ -> Observable<DrawResult?> in
                drawService?.fetchDraw()
                    .map { Optional($0) }
                    .do(onNext: { _ in isLoadingRelay.onNext(false) }) // hide spinner
                ?? .just(nil)
            }
            .startWith(nil)
            .share(replay: 1)
    }

    // MARK: - Pure validation — no RxSwift here, just plain Swift
    // Returns nil if valid, or an error message string if invalid.
    static func validate(_ numbers: [Int]) -> String? {
        guard numbers.count == 6 else {
            return "Pick exactly 6 numbers (you have \(numbers.count))"
        }
        guard numbers.allSatisfy((1...45).contains) else {
            return "All numbers must be between 1 and 45"
        }
        guard Set(numbers).count == numbers.count else {
            return "Numbers must be unique — no duplicates"
        }
        return nil
    }
}
