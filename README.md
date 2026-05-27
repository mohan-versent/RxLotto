# RxLotto 🎰

A learning project built to understand **RxSwift** and **MVVM** in a UIKit app — the reactive programming pattern used in many large-scale iOS codebases.

## What it does

A lotto entry form where the user types 6 numbers (1–45). The UI reacts in real-time:

- ✅ Validates as you type — shows descriptive error messages
- 🟢 Submit button only enables when the entry is valid
- 🔄 Hitting "Check My Entry" simulates a 1.5s network call to fetch draw results
- 🏆 Shows how many of your numbers matched the winning draw

## Architecture

```
MVVM + RxSwift

ViewController  →  sends raw user events into ViewModel (inputs)
ViewModel       →  transforms, validates, exposes Observable outputs
ViewController  →  binds ViewModel outputs to UI elements (no logic here)
```

```
RxLotto/
├── Models/
│   ├── LottoEntry.swift          # Value type — 6 validated numbers + match logic
│   └── DrawResult.swift          # Value type — winning numbers from the draw
├── Services/
│   └── DrawService.swift         # Simulates an API call using Observable.create
├── ViewModels/
│   └── EntryViewModel.swift      # All RxSwift logic lives here
├── Views/
│   └── EntryViewController.swift # UIKit view — only wires inputs/outputs, zero logic
└── Resources/
    └── Info.plist
```

## RxSwift concepts demonstrated

| Concept | Where | What it does |
|---------|-------|--------------|
| `BehaviorSubject` | `entryText` | Holds the current text field value + emits to new subscribers |
| `PublishSubject` | `submitTapped` | Fires only on new button taps — no stored value |
| `DisposeBag` | VC + VM | Cancels all subscriptions when the owner is deallocated |
| `debounce` | `parsed` chain | Waits 300ms after typing stops before processing |
| `distinctUntilChanged` | `parsed` chain | Skips emission if value didn't actually change |
| `filter` | `parsed` chain | Ignores empty input so the placeholder message stays visible |
| `map` | `isValid`, `validationMessage` | Transforms `[Int]` → `Bool` or `String` |
| `flatMapLatest` | `drawResult` | Cancels the previous API call if user submits again |
| `withLatestFrom` | `drawResult` | Grabs the latest parsed numbers when submit is tapped |
| `share(replay: 1)` | `parsed` | One upstream execution feeds multiple downstream subscribers |
| `startWith` | `isValid`, `validationMessage` | Provides an initial value before user interacts |
| `compactMap` | `drawResult` | Skips nil (the initial empty value) |
| `rx.text.orEmpty` | VC binding | RxCocoa — turns UITextField into `Observable<String>` |
| `rx.tap` | VC binding | RxCocoa — turns UIButton tap into `Observable<Void>` |
| `rx.isEnabled` | VC binding | RxCocoa — drives button enabled state from Observable |
| `rx.isAnimating` | VC binding | RxCocoa — drives activity spinner from Observable |
| `bind(to:)` | VC binding | Subscribes and pushes values into a Subject or UI property |

## Key mental model

```
BehaviorSubject  =  a variable that is also a stream
Observable       =  a read-only stream you can transform with operators
DisposeBag       =  a bag that cancels all streams when the owner dies
bind(to:)        =  subscribe + push value into a UI element or Subject
share(replay:1)  =  one upstream, multiple watchers (like a TV broadcast)
```

**C# / .NET equivalents:**

| RxSwift | .NET |
|---------|------|
| `Observable<T>` | `IObservable<T>` |
| `BehaviorSubject<T>` | `BehaviorSubject<T>` (Rx.NET) |
| `PublishSubject<T>` | `Subject<T>` (Rx.NET) |
| `DisposeBag` | `CompositeDisposable` |
| `share(replay:1)` | `.Replay(1).RefCount()` |
| `flatMapLatest` | `Switch()` / `SelectMany` with cancellation |
| `debounce` | `Throttle` |

## The binding pattern (how ViewController talks to ViewModel)

```swift
// INPUT: VC sends raw events into VM
numberTextField.rx.text.orEmpty
    .bind(to: viewModel.entryText)
    .disposed(by: disposeBag)

// OUTPUT: VM result drives UI — ViewController has zero validation logic
viewModel.isValid
    .bind(to: submitButton.rx.isEnabled)
    .disposed(by: disposeBag)

viewModel.validationMessage
    .bind(to: validationLabel.rx.text)
    .disposed(by: disposeBag)
```

## Requirements

- Xcode 15+
- iOS 16+
- Swift 5.9
- RxSwift 6.5.0 (resolved via Swift Package Manager)

## Running the project

```bash
git clone https://github.com/brightmohan/RxLotto.git
cd RxLotto
open RxLotto.xcodeproj
```

Xcode will automatically resolve RxSwift 6.5.0 via SPM on first open (~30 seconds). Build and run on any iOS 16+ simulator.

## Running tests

```bash
# In Xcode: Cmd+U
# Or via command line:
xcodebuild test \
  -project RxLotto.xcodeproj \
  -scheme RxLotto \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Tests cover:
- Pure validation logic (`validate(_:)`)
- `LottoEntry.matchCount(against:)` — 0 matches, partial matches, jackpot
- Observable outputs — `isValid` starts false, becomes true for valid input
- `validationMessage` shows `⚠️` prefix for invalid input
