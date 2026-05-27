// The result of a lotto draw — 6 randomly picked winning numbers
struct DrawResult {
    let winningNumbers: [Int]

    var displayString: String {
        winningNumbers.sorted().map(String.init).joined(separator: "  ")
    }
}
