import Foundation

/// Operator for an open range expressed in reverse order ("downto"). The "open" end is the _first_ parameter.
infix operator >>>: RangeFormationPrecedence

/// Implementation of the preceding.
func >>><Bound>(maximum: Bound, minimum: Bound) -> ReversedCollection<Range<Bound>> where Bound: Strideable {
    return (minimum..<maximum).reversed()
}

/// Operator for an open range: synonym for `..<`, re-expressed for symmetry with the preceding.
infix operator <<<: RangeFormationPrecedence

/// Implementation of the preceding.
func <<<<Bound>(minimum: Bound, maximum: Bound) -> Range<Bound> where Bound: Strideable {
    return (minimum..<maximum)
}

