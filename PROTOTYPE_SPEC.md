# Prototype Game Design 2 Spec

## Goal

Build a mechanics-first prototype for a spherical puzzle-action game inspired by Magical Drop.

The sphere is the board. The player orbits around it and manipulates exposed tiles along fault lines and chasms. The early prototype should prove whether grabbing, holding, placing, and opening more play area feels good before adding enemies, scoring, or advanced visuals.

## Core Fantasy

- The player is not shooting a shield.
- The player is peeling apart and rearranging a living spherical shell.
- Fault lines are the entry points into the shell.
- Creating combos tears the shell open into wider chasms.
- The enemy will eventually try to repair and refill the shell.

## First Playable Loop

1. The sphere starts covered in colored tiles.
2. A fault line exposes a limited set of tiles.
3. The player orbits the sphere and targets exposed tiles near their current position.
4. The player grabs one color and can keep collecting more exposed tiles of that same color into a held stack.
5. The player releases the held stack onto a valid exposed destination.
6. If the placement creates a connected group of 3 or more same-color tiles, that group pops.
7. Popped tiles become empty cells.
8. Empty cells expose neighboring covered tiles, expanding the playable chasm.

## Locked Rules For Prototype 1

### Colors

- Use 3 colors: red, blue, yellow.

### Exposure

- A tile is exposed if it borders a fault line or an empty cell.
- Only exposed tiles are interactable.

### Grab

- The player starts a grab from one exposed tile.
- The first grabbed tile locks the held color.
- While the player is holding, they may collect additional exposed tiles of the same color.
- Tiles of other colors cannot be added until the current held stack is released.
- The held stack is one active inventory; no second stack.

### Place

- Releasing places the held stack onto a valid exposed destination.
- Placement must follow a deterministic local path so the player can learn it.
- For the first implementation, placement should favor the nearest valid cells extending away from the target edge.

### Pop

- Connected groups of 3 or more same-color tiles pop immediately after placement resolves.
- Pop checks are adjacency-based, not line-based.
- Chain reactions are optional for the first pass and can be added later.

### Board Growth

- When tiles pop, those cells become empty.
- Neighboring filled cells that now border the empty region become exposed.
- This is how a fault line grows into a chasm and creates more play area.

## Out Of Scope For Prototype 1

- Enemy refill behavior
- Scoring
- Boss health or weak-point damage
- Lock tiles, special tiles, corruption, hazards
- Full VFX pass
- Full UI pass
- Mobile controls

## Board Model

The gameplay should be driven by board data, not by mesh collision.

Each cell should store:

- `id`
- `neighbors`
- `color`
- `filled`
- `exposed`
- `visible`
- `surface_position`

The board should be represented as a spherical graph or wrapped tile network. Rendering should read from that data model.

## Recommended System Split

### Player Orbit

Responsible for:

- Orbit movement around the sphere
- Camera-relative movement frame
- Local target selection near the player-facing side of the sphere

Existing foundation:

- [`scripts/player_ship.gd`](/Users/leehuffman/Documents/New%20project/prototype-game-design-2/scripts/player_ship.gd)

### Sphere Board

Responsible for:

- Owning all cells and neighbor relationships
- Tracking exposure
- Applying grab/place/pop results

Suggested script:

- `scripts/sphere_board.gd`

### Grab/Place Resolver

Responsible for:

- Starting and maintaining the held stack
- Validating same-color grabs
- Resolving deterministic placement paths

Suggested script:

- `scripts/board_interactor.gd`

### Combo Resolver

Responsible for:

- Finding connected same-color groups
- Returning pop results
- Triggering exposure recalculation

This can start inside `sphere_board.gd` and be split later.

### Renderer

Responsible for:

- Turning board state into visible tiles on the sphere
- Highlighting exposed tiles
- Showing held stack and targeted cell

Suggested script:

- `scripts/sphere_board_renderer.gd`

## First Engineering Milestone

Build a non-final board with one fault line at the equator and prove the loop.

Deliverable:

- Sphere with visible tile cells
- Equator fault line exposes initial cells
- Player can orbit around sphere
- Player can highlight exposed tiles near the current side of the sphere
- Player can grab multiple exposed tiles of one color
- Player can place held tiles onto another exposed edge
- Connected groups of 3+ pop
- New neighboring cells become exposed

Success criteria:

- The player can understand what is interactable without explanation.
- Holding a color and setting up a combo feels deliberate.
- Popping tiles clearly expands the board.
- Orbiting the sphere creates meaningful positional decisions.

## Immediate Build Order

1. Replace old shield-specific logic with a board-driven sphere model.
2. Create a minimal spherical cell graph with an equator fault line.
3. Render cells with simple colored placeholder visuals.
4. Add targeting/highlighting for exposed cells near the player-facing side.
5. Implement held-stack grabbing.
6. Implement deterministic placement.
7. Implement connected-group pop detection.
8. Recompute exposure after pops.

## Git / GitHub Plan

The workspace root is currently one uncommitted git repository with many unrelated folders. To keep this prototype clean:

1. Commit only the `prototype-game-design-2` project files, not the whole workspace.
2. Use small commits by milestone:
   - `orbit prototype`
   - `sphere board scaffold`
   - `grab/place loop`
   - `combo and exposure`
3. Before pushing to GitHub, either:
   - create a dedicated repo from `prototype-game-design-2`, or
   - keep the root repo but commit only that folder intentionally

Recommended near-term practice:

- make one commit after each working milestone
- keep prototype notes in this file so commit history matches the design

## Open Questions

- Does grabbing collect tiles one at a time or by dragging through same-color exposed tiles?
- What exact local direction should placement follow from a release point?
- Should chain reactions be in prototype 1 or prototype 2?
- How large should the first visible playable band around the equator be?
