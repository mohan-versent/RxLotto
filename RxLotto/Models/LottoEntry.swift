// A validated lotto entry — exactly 6 unique numbers from 1 to 45
struct LottoEntry {
    let numbers: [Int]

    // Returns how many numbers match the draw result
    func matchCount(against draw: DrawResult) -> Int {
        Set(numbers).intersection(Set(draw.winningNumbers)).count
    }
}
