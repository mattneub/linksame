/// State passed from the processor to the presenter for display in the interface.
/// It is also used to store state generally.
struct BoardState {
    /// Variable where we maintain the contents of the "deck" at the start of each stage,
    /// in case we are asked to restart the stage. The "deck" consists of just a list of pictures,
    /// because we know where the corresponding pieces go: just fill the grid.
    var deckAtStartOfStage = [PieceReducer]()
    var hilitedPieces = [PieceReducer]()
    /// Variable where we maintain a legal path after every change in the grid, so that we know
    /// the path without performing the calculation when we really need it.
    var hintPath: Path?
    var pathViewTappable = false
    var stageNumber = 0

}
