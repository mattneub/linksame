import Foundation

/// Protocol expressing the public face of the gravity object, so we can test.
@MainActor
protocol GravityType {
    func exerciseGravity(grid: inout Grid, stageNumber: Int) -> [Movendum]
}

/// Auxiliary object, servant of the Board, that understands the concept and effects of gravity.
/// This isolates the rather elaborate gravity function into a separate place, for neatness
/// and testing.
@MainActor
final class Gravity: GravityType {
    
    /// Look for blank spaces, and move pieces into them in accordance with gravity rules for the
    /// given stage number.
    /// - Parameters:
    ///   - grid: The grid, which we are permitted to modify.
    ///   - stageNumber: The current stage number.
    /// - Returns: A list of the changes we performed in the grid.
    ///
    /// The point here is separation of responsibilities. We know nothing of the physical pieces
    /// in the interface. So we perform the gravity movements on the grid, and we hand back a list
    /// of the movements for the benefit of the caller. Of course, the caller had better hand this
    /// list over to the presenter for exercising at the interface level; otherwise, the grid and
    /// the interface will be out of sync.
    func exerciseGravity(grid: inout Grid, stageNumber: Int) -> [Movendum] {
        // Maintain a list of all pieces that need to animate a position change
        var movenda = [Movendum]() //

        // This is the core of what we do — what it means to move a piece.
        // Add the needed move to the movenda list.
        // Also _perform_ the move in the grid.
        // This puts the grid and the interface momentarily out of sync, but that's
        // the concern of the caller.
        func movePiece(_ piece: PieceReducer, to newSlot: Slot) {
            movenda.append(Movendum(piece: piece, newSlot: newSlot))
            grid[column: piece.column, row: piece.row] = nil
            grid[column: newSlot.column, row: newSlot.row] = piece.picName
        }

        // close up! depends on what stage we are in
        // the following code is really ugly and repetitive, every case being modelled on the same template
        // but it works and I'm not touching it!
        switch stageNumber {
        case 0: // no gravity, do nothing
            // fallthrough // debugging later cases
            break
        case 1: // gravity down
            // fallthrough // debugging later cases
            for x in 0..<grid.columns {
                for y in grid.rows>>>0 { // not an exact match for my original C version, but simpler
                    let piece = grid[column: x, row: y]
                    if piece == nil {
                        for yt in y>>>0 {
                            let piece2 = grid[column: x, row: yt]
                            if piece2 == nil {
                                continue
                            }
                            movePiece(piece2!, to: Slot(x,y))
                            break
                        }
                    }
                }
            }
        case 2: // gravity right
            // fallthrough // debugging later cases
            for y in 0..<grid.rows {
                for x in grid.columns>>>0 {
                    let piece = grid[column: x, row: y]
                    if piece == nil {
                        for xt in x>>>0 {
                            let piece2 = grid[column: xt, row: y]
                            if piece2 == nil {
                                continue
                            }
                            movePiece(piece2!, to: Slot(x,y))
                            break
                        }
                    }
                }
            }
        case 3: // gravity toward central horiz line
            // fallthrough // debugging later cases
            let center = grid.rows/2 // integer div, deliberate
            // exactly like 1 except we have to do it twice in two directions
            for x in 0..<grid.columns {
                for y in center>>>0 {
                    let piece = grid[column: x, row: y]
                    if piece == nil {
                        for yt in y>>>0 {
                            let piece2 = grid[column: x, row: yt]
                            if piece2 == nil {
                                continue
                            }
                            movePiece(piece2!, to: Slot(x,y))
                            break
                        }
                    }
                }
                for y in center..<grid.rows {
                    let piece = grid[column: x, row: y]
                    if piece == nil {
                        for yt in y+1..<grid.rows {
                            let piece2 = grid[column: x, row: yt]
                            if piece2 == nil {
                                continue
                            }
                            movePiece(piece2!, to: Slot(x,y))
                            break
                        }
                    }
                }
            }
        case 4: // gravity toward central vertical line
            // fallthrough // debugging later cases
            // exactly like 3 except the other orientation
            let center = grid.columns/2 // integer div, deliberate
            for y in 0..<grid.rows {
                for x in center>>>0 {
                    let piece = grid[column: x, row: y]
                    if piece == nil {
                        for xt in x>>>0 {
                            let piece2 = grid[column: xt, row: y]
                            if piece2 == nil {
                                continue
                            }
                            movePiece(piece2!, to: Slot(x,y))
                            break
                        }
                    }
                }
                for x in center..<grid.columns {
                    let piece = grid[column: x, row: y]
                    if piece == nil {
                        for xt in x+1..<grid.columns {
                            let piece2 = grid[column: xt, row: y]
                            if piece2 == nil {
                                continue
                            }
                            movePiece(piece2!, to: Slot(x,y))
                            break
                        }
                    }
                }
            }
        case 5: // gravity away from central horiz line
            // fallthrough // debugging later cases
            // exactly like 3 except we walk from the outside to the center
            let center = grid.rows/2 // integer div, deliberate
            for x in 0..<grid.columns {
                for y in grid.rows>>>center { // not identical to C loop, moved pivot
                    let piece = grid[column: x, row: y]
                    if piece == nil {
                        for yt in y>>>center {
                            let piece2 = grid[column: x, row: yt]
                            if piece2 == nil {
                                continue
                            }
                            movePiece(piece2!, to: Slot(x,y))
                            break
                        }
                    }
                }
                for y in 0..<center {
                    let piece = grid[column: x, row: y]
                    if piece == nil {
                        for yt in y+1..<center {
                            let piece2 = grid[column: x, row: yt]
                            if piece2 == nil {
                                continue
                            }
                            movePiece(piece2!, to: Slot(x,y))
                            break
                        }
                    }
                }
            }
        case 6: // gravity away from central vertical line
            // fallthrough // debugging later cases
            // exactly like 4 except we start at the outside
            let center = grid.columns/2 // integer div, deliberate
            for y in 0..<grid.rows {
                for x in grid.columns>>>center {
                    let piece = grid[column: x, row: y]
                    if piece == nil {
                        for xt in x>>>center {
                            let piece2 = grid[column: xt, row: y]
                            if piece2 == nil {
                                continue
                            }
                            movePiece(piece2!, to: Slot(x,y))
                            break
                        }
                    }
                }
                for x in 0..<center {
                    let piece = grid[column: x, row: y]
                    if piece == nil {
                        for xt in x..<center { // not identical
                            let piece2 = grid[column: xt, row: y]
                            if piece2 == nil {
                                continue
                            }
                            movePiece(piece2!, to: Slot(x,y))
                            break
                        }
                    }
                }
            }
        case 7: // gravity down in one half, gravity up in the other half
            // fallthrough // debugging later cases
            // like doing 1 in two pieces with the second piece in reverse direction
            let center = grid.columns/2;
            // for (var x = 0; x < center; x++) {
            for x in 0..<center {
                for y in grid.rows>>>0 {
                    let piece = grid[column: x, row: y]
                    if piece == nil {
                        for yt in y>>>0 {
                            let piece2 = grid[column: x, row: yt]
                            if piece2 == nil {
                                continue
                            }
                            movePiece(piece2!, to: Slot(x,y))
                            break
                        }
                    }
                }
            }
            for x in center..<grid.columns {
                for y in 0..<grid.rows {
                    let piece = grid[column: x, row: y]
                    if piece == nil {
                        for yt in y..<grid.rows {
                            let piece2 = grid[column: x, row: yt]
                            if piece2 == nil {
                                continue
                            }
                            movePiece(piece2!, to: Slot(x,y))
                            break
                        }
                    }
                }
            }
        case 8: // gravity left in one half, gravity right in other half
            // like doing 2 in two pieces with second in reverse direction
            let center = grid.rows/2
            for y in 0..<center {
                for x in grid.columns>>>0 {
                    let piece = grid[column: x, row: y]
                    if piece == nil {
                        for xt in x>>>0 {
                            let piece2 = grid[column: xt, row: y]
                            if piece2 == nil {
                                continue
                            }
                            movePiece(piece2!, to: Slot(x,y))
                            break
                        }
                    }
                }
            }
            for y in center..<grid.rows {
                for x in 0..<grid.columns {
                    let piece = grid[column: x, row: y]
                    if piece == nil {
                        for xt in x..<grid.columns {
                            let piece2 = grid[column: xt, row: y]
                            if piece2 == nil {
                                continue
                            }
                            movePiece(piece2!, to: Slot(x,y))
                            break
                        }
                    }
                }
            }

        default:
            break
        }

        return movenda
    }
}
