import RxSwift
import Foundation

// Simulates calling a lotto draw API.
// In the real codebase this would be an OpenAPI-generated client.
class DrawService {

    // Returns an Observable that emits one DrawResult after a fake 1.5s network delay.
    // Observable = "a stream that will produce a value at some point"
    func fetchDraw() -> Observable<DrawResult> {
        return Observable.create { observer in
            DispatchQueue.global().asyncAfter(deadline: .now() + 1.5) {
                let winning = Array((1...45).shuffled().prefix(6))
                observer.onNext(DrawResult(winningNumbers: winning))
                observer.onCompleted()
            }
            // Return a Disposable — called when subscriber cancels (e.g. VC is dismissed)
            return Disposables.create()
        }
        .observe(on: MainScheduler.instance) // always deliver result on main thread
    }
}
