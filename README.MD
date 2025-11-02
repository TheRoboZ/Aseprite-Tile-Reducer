# Tile Reducer for Aseprite TileMaps

This Aseprite script optimizes tile set size in TileMap layers by identifying groups of tiles with minimal pixel differences, based on a user-defined threshold. It leverages Aseprite's native TileMap support to preserve existing tile symmetry within the map.

Users can interactively select tiles within each group for replacement and designate a master tile to overwrite the selected ones, enabling efficient reduction of tile set size while maintaining visual consistency.

## Features
- **Threshold-Based Similarity Detection**: Groups tiles by pixel difference thresholds to identify near-identical variants.
- **Interactive Tile Management**: Visualize and select tiles for replacement, with clear visual indicators for masters, selections, and inspections.
- **Non-Destructive Workflow**: Generates a new TileMap layer for the optimized result, allowing iterative refinements without altering originals.
- **Visual Diff Support**: Optional difference blending mode for quick inspection of changes.

## Requirements
- Aseprite (version supporting TileMaps, e.g., v1.2.7 or later).
- A project with at least one TileMap layer.

## Installation
1. Save the script as a `.lua` file in your Aseprite scripts directory (e.g., `Aseprite/scripts/` on Windows/Mac or `~/.config/aseprite/scripts/` on Linux).
2. Restart Aseprite or refresh the Scripts menu (File > Scripts > Refresh).

## Usage Instructions
Follow these steps to run the script and optimize your TileMap:

1. **Select a TileMap Layer**: In the Layers panel, click to select the target TileMap layer.

2. **Invoke the Script**: Go to File > Scripts > [Your Script Name] to launch the tool.

3. **Set the Threshold**: Enter the desired pixel difference threshold (max value is half Tile Area, lower values yield stricter similarity matching).

4. **Find Similar Tiles**: Click the **FIND** button. A new dialog will open, displaying groups of similar tiles (one group per row, up to 16 rows per page). Use the arrow buttons to navigate pages.

5. **Manage Tile Groups**:
   - **Master Tile**: The tile with a yellow bottom border is the default **MASTER** for the group. It will overwrite all selected tiles in the group.
   - **Set a New Master**: Right-click any tile in the group to designate it as the MASTER (only one per group).
   - **Select for Replacement**: Double-click a tile to mark it for replacement (red outline appears).
   - **Inspect Differences**: Left-click a tile to compare it against the MASTER:
     - Inspected tiles show a blue top border (or blue outline if selected).
     - The inspected MASTER shows a green bottom border.
     - A preview highlights pixel differences.

6. **Apply Changes**: Once selections are complete across all groups, click **APPLY**.
   - A new TileMap layer is created with the reduced tile set, where selected tiles are replaced by their group's MASTER.
   - Check **Create diff. layer** to apply Difference blending mode to the new layer for visual verification of changes.

7. **Iterate for Further Optimization**: Repeat the process on the new layer to refine results further. Original layers and tile sets remain intact for reference.

## Limitations
- Only operates on selected TileMap layers; other layer types are ignored.
- Large tile sets may require multiple pages—use navigation efficiently.

## Contributing
If you encounter issues or have suggestions, please open an issue or submit a pull request on the project's repository.

## License
This script is provided under the MIT License. See `LICENSE` for details.

---

*Version 1.1 | Last Updated: November 2025*