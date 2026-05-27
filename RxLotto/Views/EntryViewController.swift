import UIKit
import RxSwift
import RxCocoa

// EntryViewController: purely a display layer.
// It creates the UI, then BINDS ViewModel outputs to UI elements.
// There is NO validation logic here — that all lives in EntryViewModel.
//
class EntryViewController: UIViewController {

    // MARK: - UI Elements
    private let instructionLabel: UILabel = {
        let label = UILabel()
        label.text = "Enter 6 numbers (1–45), comma separated"
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private let numberTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "e.g.  7, 14, 22, 33, 41, 45"
        tf.borderStyle = .roundedRect
        tf.keyboardType = .numbersAndPunctuation
        tf.clearButtonMode = .whileEditing
        tf.font = .monospacedSystemFont(ofSize: 18, weight: .medium)
        tf.textAlignment = .center
        return tf
    }()

    private let validationLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private let submitButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Check My Entry"
        config.cornerStyle = .large
        config.baseBackgroundColor = .systemGreen
        let button = UIButton(configuration: config)
        button.isEnabled = false
        return button
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        return indicator
    }()

    private let resultCard: UIView = {
        let view = UIView()
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 16
        view.isHidden = true
        return view
    }()

    private let winningNumbersLabel: UILabel = {
        let label = UILabel()
        label.font = .monospacedSystemFont(ofSize: 24, weight: .bold)
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private let matchLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textAlignment = .center
        return label
    }()

    // MARK: - RxSwift
    // DisposeBag lives on the ViewController.
    // When the VC is deallocated, all bindings are cancelled automatically.
    private let disposeBag = DisposeBag()
    private let viewModel = EntryViewModel()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "🎰 RxLotto Entry"
        view.backgroundColor = .systemBackground
        setupLayout()
        bindViewModel()   // ← all RxSwift wiring happens here
    }

    // MARK: - Layout (plain UIKit, nothing RxSwift-specific)
    private func setupLayout() {
        let resultStack = UIStackView(arrangedSubviews: [winningNumbersLabel, matchLabel])
        resultStack.axis = .vertical
        resultStack.spacing = 8
        resultStack.translatesAutoresizingMaskIntoConstraints = false
        resultCard.addSubview(resultStack)

        let stack = UIStackView(arrangedSubviews: [
            instructionLabel,
            numberTextField,
            validationLabel,
            submitButton,
            activityIndicator,
            resultCard
        ])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 32),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            numberTextField.heightAnchor.constraint(equalToConstant: 52),
            submitButton.heightAnchor.constraint(equalToConstant: 52),
            resultCard.heightAnchor.constraint(greaterThanOrEqualToConstant: 100),

            resultStack.topAnchor.constraint(equalTo: resultCard.topAnchor, constant: 16),
            resultStack.bottomAnchor.constraint(equalTo: resultCard.bottomAnchor, constant: -16),
            resultStack.leadingAnchor.constraint(equalTo: resultCard.leadingAnchor, constant: 16),
            resultStack.trailingAnchor.constraint(equalTo: resultCard.trailingAnchor, constant: -16),
        ])
    }

    // MARK: - RxSwift Bindings
    // This is the key method — read top to bottom like a wiring diagram.
    // Every line either:
    //   A) sends ViewController events INTO the ViewModel (inputs), or
    //   B) takes ViewModel outputs and drives UI elements (outputs)
    //
    private func bindViewModel() {

        // === INPUTS: ViewController → ViewModel ===

        // RxCocoa: .rx.text turns UITextField into an Observable<String?>
        // .orEmpty converts String? → String (nil becomes "")
        // bind(to:) subscribes and pushes values into the BehaviorSubject
        numberTextField.rx.text.orEmpty
            .bind(to: viewModel.entryText)
            .disposed(by: disposeBag)

        // RxCocoa: .rx.tap turns UIButton into an Observable<Void>
        submitButton.rx.tap
            .bind(to: viewModel.submitTapped)
            .disposed(by: disposeBag)

        // === OUTPUTS: ViewModel → UI ===

        // Bind validation message text
        viewModel.validationMessage
            .bind(to: validationLabel.rx.text)
            .disposed(by: disposeBag)

        // Bind isValid to button enabled state
        // When isValid emits true → button becomes enabled (green)
        // When isValid emits false → button stays disabled (grey)
        viewModel.isValid
            .bind(to: submitButton.rx.isEnabled)
            .disposed(by: disposeBag)

        // Bind isLoading to spinner
        // RxCocoa: .rx.isAnimating drives UIActivityIndicatorView
        viewModel.isLoading
            .bind(to: activityIndicator.rx.isAnimating)
            .disposed(by: disposeBag)

        // Bind isLoading to hide/show the submit button while loading
        viewModel.isLoading
            .map { !$0 }                             // invert: loading=true → button hidden
            .bind(to: submitButton.rx.isEnabled)
            .disposed(by: disposeBag)

        // Bind draw result to the result card
        // subscribe(onNext:) = "do this side effect when a new value arrives"
        viewModel.drawResult
            .compactMap { $0 }                       // skip nil (initial value)
            .subscribe(onNext: { [weak self] result in
                self?.showResult(result)
            })
            .disposed(by: disposeBag)
    }

    // MARK: - Result Display
    private func showResult(_ draw: DrawResult) {
        // Parse the current entry to calculate matches
        let currentText = (try? viewModel.entryText.value()) ?? ""
        let pickedNumbers = currentText
            .components(separatedBy: CharacterSet(charactersIn: ", "))
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        let entry = LottoEntry(numbers: pickedNumbers)
        let matches = entry.matchCount(against: draw)

        winningNumbersLabel.text = "🏆 Draw: \(draw.displayString)"
        matchLabel.text = matchMessage(for: matches)
        matchLabel.textColor = matches >= 3 ? .systemGreen : .secondaryLabel

        UIView.animate(withDuration: 0.3) {
            self.resultCard.isHidden = false
        }
    }

    private func matchMessage(for matches: Int) -> String {
        switch matches {
        case 6: return "🎉 JACKPOT! All 6 matched!"
        case 5: return "🥇 5 matched — Division 2!"
        case 4: return "🥈 4 matched — Division 3!"
        case 3: return "🥉 3 matched — Division 4!"
        default: return "😅 \(matches) matched — better luck next time"
        }
    }
}
