#import <Cocoa/Cocoa.h>
#import "EdgeTabGeometry.h"

static void Expect(BOOL condition, NSString *message)
{
    if (!condition) { NSLog(@"FAIL: %@", message); exit(1); }
}

int main(void)
{
    @autoreleasepool {
        NSSize tab = NSMakeSize(14, 58);
        NSSize drawer = NSMakeSize(240, 400);
        // A monitor left of the primary, with a side Dock and bottom offset.
        NSRect visible = NSMakeRect(-1840, 80, 1776, 1000);
        NSRect left = BarCalEdgeTabFrame(visible, YES, 0.5, tab);
        NSRect right = BarCalEdgeTabFrame(visible, NO, 0.5, tab);
        Expect(NSMinX(left) == NSMinX(visible), @"Left tab respects the visible screen's origin");
        Expect(NSMaxX(right) == NSMaxX(visible), @"Right tab stays against the usable edge");
        for (NSNumber *position in @[@(-2), @0, @0.5, @1, @3, @(NAN)]) {
            for (NSNumber *edge in @[@NO, @YES]) {
                NSRect handle = BarCalEdgeTabFrame(visible, edge.boolValue, position.doubleValue, tab);
                NSRect panel = BarCalEdgeDrawerFrame(visible, handle, edge.boolValue, drawer);
                Expect(NSContainsRect(visible, handle), @"Tab position is clamped, including invalid saved values");
                Expect(NSContainsRect(visible, panel), @"Drawer stays inside the visible display at both extremes");
                Expect(edge.boolValue ? NSMinX(panel) == NSMinX(visible) : NSMaxX(panel) == NSMaxX(visible), @"Drawer opens inward from its own edge");
                NSRect attached = BarCalEdgeAttachedTabFrame(panel, handle, edge.boolValue);
                Expect(NSIntersectsRect(panel, attached), @"Notch overlaps the drawer to cover its border seam");
                Expect(NSWidth(NSIntersectionRect(panel, attached)) == 1, @"Join overlap stays one point on either side");
                Expect(NSMinY(attached) >= NSMinY(panel) + 20 && NSMaxY(attached) <= NSMaxY(panel) - 20, @"Notch joins the straight edge clear of rounded corners");
                Expect(edge.boolValue ? NSMaxX(attached) > NSMaxX(panel) : NSMinX(attached) < NSMinX(panel), @"Notch protrudes inward into the display");
                Expect(NSMinY(attached) == NSMinY(handle), @"Notch keeps its vertical position for a horizontal reveal, even at either extreme");

                NSSize surfaceSize = NSMakeSize(drawer.width + tab.width - 1, drawer.height);
                NSRect surface = BarCalEdgeDrawerFrame(visible, handle, edge.boolValue, surfaceSize);
                NSRect body = surface;
                body.size.width -= tab.width - 1;
                if (!edge.boolValue) body.origin.x += tab.width - 1;
                NSRect unifiedTab = BarCalEdgeAttachedTabFrame(body, handle, edge.boolValue);
                CGFloat offset = NSMinX(handle) - NSMinX(unifiedTab);
                Expect(NSEqualRects(NSOffsetRect(unifiedTab, offset, 0), handle), @"Moving the unified surface starts exactly at the collapsed notch");
                Expect(NSWidth(NSIntersectionRect(NSOffsetRect(body, offset, 0), visible)) <= 1, @"The calendar stays clipped beyond the screen edge at the start of its slide");
            }
        }
        NSRect upper = NSMakeRect(250, 1200, 1400, 820);
        NSRect panel = BarCalEdgeDrawerFrame(upper, BarCalEdgeTabFrame(upper, NO, 1, tab), NO, drawer);
        Expect(NSContainsRect(upper, panel), @"A display above the primary uses its own coordinate space");

        // Browser-style strips use two adjacent tabs but retain the same
        // continuous reveal and drag geometry as the single-notch option.
        for (NSValue *value in @[[NSValue valueWithSize:NSMakeSize(14, 58)], [NSValue valueWithSize:NSMakeSize(14, 104)]]) {
            NSSize strip = value.sizeValue;
            NSSize surfaceSize = NSMakeSize(drawer.width + strip.width - 1, drawer.height);
            for (NSNumber *edge in @[@NO, @YES]) for (NSNumber *position in @[@0, @0.5, @1]) {
                NSRect collapsed = BarCalEdgeTabFrame(visible, edge.boolValue, position.doubleValue, strip);
                NSRect surface = BarCalEdgeDrawerFrame(visible, collapsed, edge.boolValue, surfaceSize);
                NSRect body = surface;
                body.size.width -= strip.width - 1;
                if (!edge.boolValue) body.origin.x += strip.width - 1;
                NSRect attached = BarCalEdgeAttachedTabFrame(body, collapsed, edge.boolValue);
                CGFloat offset = NSMinX(collapsed) - NSMinX(attached);
                Expect(NSContainsRect(visible, surface) && NSContainsRect(visible, collapsed), @"Both tab layouts fit at either vertical extreme");
                Expect(NSEqualRects(NSOffsetRect(attached, offset, 0), collapsed), @"Both tab layouts start their reveal exactly at the collapsed strip");
                CGFloat previousProgress = -1;
                for (NSNumber *distance in @[@0, @8, @30, @90, @(fabs(offset)), @(fabs(offset) + 50)]) {
                    CGFloat inward = distance.doubleValue;
                    CGFloat liveOffset = BarCalEdgePullOffset(offset, edge.boolValue ? inward : -inward);
                    CGFloat progress = BarCalEdgePullProgress(offset, liveOffset);
                    Expect(progress >= previousProgress && progress >= 0 && progress <= 1, @"Pulling inward reveals content continuously on either side");
                    previousProgress = progress;
                    NSRect liveTab = NSOffsetRect(attached, liveOffset, 0);
                    CGFloat travel = MIN(inward, fabs(offset));
                    Expect(NSMinX(liveTab) == NSMinX(collapsed) + (edge.boolValue ? travel : -travel), @"Tabs track the pointer exactly until fully extended");
                    CGFloat visibleContent = NSWidth(NSIntersectionRect(NSOffsetRect(body, liveOffset, 0), visible));
                    Expect(fabs(visibleContent - MIN(NSWidth(body), 1 + travel)) < 0.01, @"The actual content becomes visible with the tabs rather than staying cut off");
                }
                CGFloat returned = BarCalEdgePullOffset(offset, 0);
                Expect(returned == offset && BarCalEdgePullProgress(offset, returned) == 0, @"Pushing back to the edge restores the collapsed state without drift");
                Expect(BarCalEdgePullOffset(offset, edge.boolValue ? -30 : 30) == offset, @"Outward drags never expose content beyond the closed endpoint");
            }
        }

        // Drag a drawer whose notch starts near its top, rather than centered.
        // Dropping it lower must preserve the panel's grab point and openness.
        for (NSNumber *edge in @[@NO, @YES]) {
            NSRect tabStart = BarCalEdgeTabFrame(visible, edge.boolValue, 0.95, tab);
            NSRect start = BarCalEdgeDrawerFrame(visible, tabStart, edge.boolValue, drawer);
            NSRect grip = BarCalEdgeAttachedTabFrame(start, tabStart, edge.boolValue);
            NSPoint pointer = NSMakePoint(NSMidX(grip) + 2, NSMidY(grip) - 7);
            NSPoint moved = NSMakePoint(pointer.x + 18, pointer.y - 120);
            NSRect dragged = BarCalEdgeDraggedFrame(start, pointer, moved);
            NSRect movedGrip = NSOffsetRect(grip, moved.x - pointer.x, moved.y - pointer.y);
            Expect(moved.x - NSMinX(dragged) == pointer.x - NSMinX(start)
                && moved.y - NSMinY(dragged) == pointer.y - NSMinY(start), @"Expanded drag keeps the exact pointer-to-panel offset");
            Expect(NSEqualSizes(dragged.size, start.size), @"Dragging never resizes the calendar");
            CGFloat anchor = (NSMidY(movedGrip) - NSMinY(dragged)) / NSHeight(dragged);
            NSRect restored = BarCalEdgeDrawerFrameAtAnchor(visible, movedGrip, edge.boolValue, drawer, anchor);
            Expect(NSMinY(restored) == NSMinY(dragged), @"Dropping preserves vertical position instead of re-centering the calendar");
            NSRect otherEdge = BarCalEdgeDrawerFrameAtAnchor(visible, movedGrip, !edge.boolValue, drawer, anchor);
            Expect(NSMinY(otherEdge) == NSMinY(dragged), @"Changing sides preserves the drag anchor");
            Expect(NSEqualRects(BarCalEdgeDraggedFrame(start, pointer, pointer), start), @"Dragging back to the starting pointer position has no accumulated drift");
            for (NSNumber *saved in @[@(-2), @0.1, @0.5, @0.9, @2, @(NAN)]) {
                CGFloat resolved = BarCalEdgeResolvedAnchor(NSMakeSize(240, 200), tab, saved.doubleValue);
                Expect(isfinite(resolved) && resolved * 200 >= 49 && resolved * 200 <= 151, @"A resized calendar keeps the notch clear of its corners");
            }
        }
        NSLog(@"PASS: edge-tab placement, clamping, invalid saved positions, and multi-display origins");
    }
    return 0;
}
