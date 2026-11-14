#import <Cocoa/Cocoa.h>

// Shared geometry keeps both screen origins and side-mounted Docks in account.
static inline NSRect BarCalEdgeTabFrame(NSRect visible, BOOL left, CGFloat fraction, NSSize tabSize)
{
    fraction = isfinite(fraction) ? MIN(MAX(fraction, 0), 1) : 0.5;
    // Keep the notch clear of the drawer's 16-point corners at either end.
    // This also lets opening and closing stay entirely horizontal.
    CGFloat margin = MIN(28, MAX(0, (NSHeight(visible) - tabSize.height) / 2));
    CGFloat travel = MAX(0, NSHeight(visible) - tabSize.height - 2 * margin);
    CGFloat x = left ? NSMinX(visible) : NSMaxX(visible) - tabSize.width;
    return NSMakeRect(x, round(NSMinY(visible) + margin + travel * fraction), tabSize.width, tabSize.height);
}

static inline CGFloat BarCalEdgeResolvedAnchor(NSSize drawerSize, NSSize tabSize, CGFloat anchor)
{
    anchor = isfinite(anchor) ? anchor : 0.5;
    CGFloat margin = MIN(0.5, (20 + tabSize.height / 2) / MAX(1, drawerSize.height));
    return MIN(MAX(anchor, margin), 1 - margin);
}

static inline NSRect BarCalEdgeDrawerFrameAtAnchor(NSRect visible, NSRect tab, BOOL left, NSSize drawerSize, CGFloat anchor)
{
    anchor = BarCalEdgeResolvedAnchor(drawerSize, tab.size, anchor);
    CGFloat x = left ? NSMinX(visible) : NSMaxX(visible) - drawerSize.width;
    CGFloat minY = NSMinY(visible) + 8;
    CGFloat maxY = MAX(minY, NSMaxY(visible) - drawerSize.height - 8);
    CGFloat y = MIN(MAX(NSMidY(tab) - drawerSize.height * anchor, minY), maxY);
    return NSMakeRect(x, round(y), drawerSize.width, drawerSize.height);
}

static inline NSRect BarCalEdgeDrawerFrame(NSRect visible, NSRect tab, BOOL left, NSSize drawerSize)
{
    return BarCalEdgeDrawerFrameAtAnchor(visible, tab, left, drawerSize, 0.5);
}

static inline NSRect BarCalEdgeDraggedFrame(NSRect initialFrame, NSPoint initialPointer, NSPoint pointer)
{
    return NSOffsetRect(initialFrame, pointer.x - initialPointer.x, pointer.y - initialPointer.y);
}

// The same signed translation works on either side: right drawers start at a
// positive offset, left drawers at a negative offset. The pointer controls it
// directly, including reversing toward the edge before releasing.
static inline CGFloat BarCalEdgePullOffset(CGFloat closedOffset, CGFloat pointerDeltaX)
{
    CGFloat proposed = closedOffset + pointerDeltaX;
    return MIN(MAX(proposed, MIN(0, closedOffset)), MAX(0, closedOffset));
}

static inline CGFloat BarCalEdgePullProgress(CGFloat closedOffset, CGFloat offset)
{
    return fabs(closedOffset) < 1 ? 1 : MIN(MAX(1 - fabs(offset / closedOffset), 0), 1);
}

static inline NSRect BarCalEdgeAttachedTabFrame(NSRect drawer, NSRect tab, BOOL left)
{
    // Overlap the drawer's thin outline so the notch has no dividing seam.
    tab.origin.x = left ? NSMaxX(drawer) - 1 : NSMinX(drawer) - tab.size.width + 1;
    // Keep the join on the straight edge, clear of the drawer's rounded corners.
    CGFloat minY = NSMinY(drawer) + 20;
    CGFloat maxY = MAX(minY, NSMaxY(drawer) - tab.size.height - 20);
    tab.origin.y = MIN(MAX(NSMinY(tab), minY), maxY);
    return tab;
}
