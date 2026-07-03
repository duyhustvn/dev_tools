# Image Background Removal Design

## Summary

Add an `Image` tool tab to the existing Flutter dev tools app. The first image feature lets users pick an icon or diagram image, remove a solid white or black background, preview the transparent result, and export the processed PNG for use in diagrams.

The first implementation targets common icon/diagram assets, not full AI subject segmentation for photos.

## Goals

- Add an `Image` destination to the current `NavigationRail`.
- Let the user pick an image file from the local machine.
- Show the original image and the processed image side by side.
- Preview transparency with a checkerboard background.
- Remove white or black backgrounds using an offline edge flood-fill algorithm.
- Keep interior white or black details when they are not connected to the image edge.
- Let the user tune background detection with simple controls.
- Export the processed image as PNG with alpha.

## Non-Goals

- No remove.bg-style person/product segmentation.
- No cloud service, API key, or network dependency.
- No batch processing in the first version.
- No advanced masking brush or manual editing tools in the first version.

## User Flow

1. The user opens the `Image` tab.
2. The empty state shows a `Pick Image` action.
3. After a supported image is selected, the tool shows original and processed previews.
4. The user clicks `Remove Background`.
5. The app detects the background from image edges and removes connected background pixels.
6. The user adjusts `Background` mode, `Tolerance`, or `Feather` if the result needs tuning.
7. The user exports the processed PNG.

## UI Design

The app already uses one top-level widget per tool and a `NavigationRail`. The new feature follows that pattern:

- Add `ImageTool` to `_tools`.
- Add a `NavigationRailDestination` with `Icons.image` and label `Image`.
- Use an `AppBar` titled `Image Tools`.
- Use a two-pane layout for original and processed previews.
- Put controls in a compact toolbar above the previews.

Controls:

- `Pick Image`: opens the platform file picker.
- `Remove Background`: disabled until an image is loaded.
- `Background`: segmented/dropdown choice with `Auto`, `Light`, and `Dark`.
- `Tolerance`: slider for color distance matching.
- `Feather`: small slider or switch for softening edges.
- `Export PNG`: disabled until a processed image exists.

## Processing Design

The algorithm is edge flood-fill:

1. Decode the selected image into RGBA pixels.
2. Determine target background color:
   - `Auto`: sample edge and corner pixels, then classify as light or dark based on luminance.
   - `Light`: target near-white pixels.
   - `Dark`: target near-black pixels.
3. Seed a queue with pixels on the image borders that match the target color within tolerance.
4. Flood-fill only connected matching pixels from the borders.
5. Set matched pixels alpha to `0`.
6. Optionally apply a light feather pass around the transparent boundary to reduce jagged edges.
7. Encode the result as PNG.

This preserves interior white or black regions, because they are removed only if they connect to the outer image edge.

## Error Handling

- If no image is selected, processing and export actions stay disabled.
- If the file picker is cancelled, the existing state remains unchanged.
- If decode fails, show a short error message and do not replace the current image.
- If processing fails, keep the original image loaded and show an error.
- For large images, previews are fit to the available pane size while processing keeps the original pixel dimensions when possible.

## Dependencies

The implementation may add Flutter/Dart packages for:

- File picking on desktop/web/mobile.
- Pixel-level image decode and PNG encode.
- Saving or downloading the processed PNG.

Package choices should be conservative and match Flutter multiplatform support.

## Testing

Add focused coverage for the low-level background removal logic:

- White edge background becomes transparent.
- Black edge background becomes transparent.
- Interior white or black icon detail is preserved when not connected to an edge.
- Tolerance controls whether near-white or near-black pixels are matched.

Add widget coverage:

- The navigation renders the new `Image` tab.
- The empty image tool state renders with disabled processing/export actions.

## Decision

Use edge flood-fill as the first implementation approach. AI segmentation and batch processing are intentionally deferred until the basic icon/diagram workflow works well.
