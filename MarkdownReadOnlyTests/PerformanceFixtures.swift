import Foundation

enum PerformanceFixtures {
    /// Generates a Markdown document of approximately `targetBytes` bytes
    /// with a realistic density of markup: headings, emphasis, links,
    /// lists, blockquotes, and closed code blocks.
    static func markdownDocument(targetBytes: Int, seed: Int) -> String {
        var generator = SplitMix64(seed: UInt64(seed))
        var output = "# Document \(seed)\n\n"

        while output.utf8.count < targetBytes {
            switch generator.next() % 6 {
            case 0:
                output += "## Section \(generator.next() % 1000)\n\n"
            case 1:
                output += "Le **terme important** et l'_accent secondaire_ dans "
                output += "une phrase de longueur ordinaire avec `du code inline`.\n\n"
            case 2:
                output += "- élément de liste avec [un lien](https://example.com/page) dedans\n"
                output += "- deuxième élément, ~~barré~~, puis du texte contenu ici\n\n"
            case 3:
                output += "> citation sur une ligne, avec du **gras** au milieu\n\n"
            case 4:
                output += "```swift\nlet value = compute(\"argument\") // commentaire\n"
                output += "return value.map { $0 * 2 }\n```\n\n"
            default:
                output += "Paragraphe ordinaire sans balisage particulier, "
                output += "destiné à représenter la majorité du contenu réel.\n\n"
            }
        }
        return output
    }
}

/// Deterministic PRNG: fixtures must be identical run-to-run, otherwise
/// measurements are not comparable.
private struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}