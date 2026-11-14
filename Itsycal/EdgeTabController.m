#import "EdgeTabController.h"
#import "EdgeTabGeometry.h"
#import "ItsycalWindow.h"
#import "Itsycal.h"
#import "Themer.h"
#import <QuartzCore/QuartzCore.h>
#import <os/log.h>

static const NSSize SingleTabSize = {14, 58};
static const NSSize BrowserTabsSize = {14, 104};

static os_log_t EdgeDragLog(void)
{
    static os_log_t log;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ log = os_log_create("com.github.kars3n.barcal", "EdgeDrag"); });
    return log;
}

static NSPoint EdgePointerForEvent(NSEvent *event)
{
    // Read the position carried by this event, not the current pointer after
    // later coalesced events. Quartz coordinates use the primary screen's top.
    if (event.CGEvent) {
        CGPoint point = CGEventGetLocation(event.CGEvent);
        return NSMakePoint(point.x, NSMaxY(NSScreen.screens.firstObject.frame) - point.y);
    }
    return [event.window convertPointToScreen:event.locationInWindow];
}

@interface EdgeHandlePanel : NSPanel
@end
@implementation EdgeHandlePanel
- (BOOL)canBecomeKeyWindow { return NO; }
- (BOOL)canBecomeMainWindow { return NO; }
@end

@interface EdgeHandleButton : NSButton
@property (nonatomic, copy) void (^beginDrag)(NSPoint point);
@property (nonatomic, copy) void (^moveDrag)(NSPoint point);
@property (nonatomic, copy) void (^finishDrag)(NSPoint point);
@property (nonatomic) BOOL expanded;
@property (nonatomic) BOOL attachedOnLeft;
@property (nonatomic) BOOL selected;
@property (nonatomic, copy) NSString *displayTitle;
@end

@implementation EdgeHandleButton
{
    NSPoint _mouseDownPoint;
    BOOL _trackingMouse;
    BOOL _didDrag;
}
- (BOOL)acceptsFirstMouse:(NSEvent *)event { return YES; }
- (void)resetCursorRects { [self addCursorRect:self.bounds cursor:NSCursor.pointingHandCursor]; }
- (void)drawRect:(NSRect)dirtyRect
{
    [(self.displayTitle.length && !self.selected ? Theme.pendingBackgroundColor : Theme.mainBackgroundColor) setFill];
    CGFloat width = NSWidth(self.bounds);
    CGFloat height = NSHeight(self.bounds);
    // The open outline blends into the body at its broad root. Mirroring it
    // makes the same notch attach to either the display edge or the drawer.
    NSBezierPath *body = [NSBezierPath bezierPath];
    [body moveToPoint:NSMakePoint(0, 0.25)];
    [body curveToPoint:NSMakePoint(width - 0.25, 14)
        controlPoint1:NSMakePoint(0, 7) controlPoint2:NSMakePoint(width - 0.25, 7)];
    [body lineToPoint:NSMakePoint(width - 0.25, height - 14)];
    [body curveToPoint:NSMakePoint(0, height - 0.25)
        controlPoint1:NSMakePoint(width - 0.25, height - 7) controlPoint2:NSMakePoint(0, height - 7)];
    if (!self.attachedOnLeft) {
        NSAffineTransform *mirror = [NSAffineTransform transform];
        [mirror translateXBy:width yBy:0];
        [mirror scaleXBy:-1 yBy:1];
        [body transformUsingAffineTransform:mirror];
    }
    [body fill];
    if (Theme.themePreference == ThemePreferenceSlate) {
        [[NSColor colorWithWhite:0.43 alpha:1] setStroke];
        body.lineWidth = 0.5;
        [body stroke];
    }
    if (self.displayTitle.length) {
        NSColor *color = self.selected ? Theme.monthTextColor : Theme.buttonTintColor;
        NSDictionary *attributes = @{NSFontAttributeName: [NSFont systemFontOfSize:9 weight:NSFontWeightMedium], NSForegroundColorAttributeName:color};
        NSSize text = [self.displayTitle sizeWithAttributes:attributes];
        [NSGraphicsContext saveGraphicsState];
        NSAffineTransform *vertical = [NSAffineTransform transform];
        [vertical translateXBy:NSMidX(self.bounds) yBy:NSMidY(self.bounds)];
        [vertical rotateByDegrees:self.attachedOnLeft ? 90 : -90];
        [vertical concat];
        [self.displayTitle drawAtPoint:NSMakePoint(-text.width / 2, -text.height / 2) withAttributes:attributes];
        [NSGraphicsContext restoreGraphicsState];
    } else {
        [(self.expanded ? Theme.todayCellColor : Theme.buttonTintColor) setFill];
        NSRect grip = NSMakeRect(NSMidX(self.bounds) - 1.5, NSMidY(self.bounds) - 9, 3, 18);
        [[NSBezierPath bezierPathWithRoundedRect:grip xRadius:1.5 yRadius:1.5] fill];
    }
}
- (void)mouseDown:(NSEvent *)event
{
    _mouseDownPoint = EdgePointerForEvent(event);
    _trackingMouse = YES;
    _didDrag = NO;
}

- (void)trackDragAtPoint:(NSPoint)point
{
    if (!_trackingMouse) return;
    if (!_didDrag && hypot(point.x - _mouseDownPoint.x, point.y - _mouseDownPoint.y) > 4) {
        _didDrag = YES;
        if (self.beginDrag) self.beginDrag(_mouseDownPoint);
    }
    if (_didDrag && self.moveDrag) self.moveDrag(point);
}

- (void)mouseDragged:(NSEvent *)event
{
    [self trackDragAtPoint:EdgePointerForEvent(event)];
    if (_didDrag) [NSCursor.closedHandCursor set];
}

- (void)mouseUp:(NSEvent *)event
{
    if (!_trackingMouse) return;
    NSPoint point = EdgePointerForEvent(event);
    [self trackDragAtPoint:point];
    _trackingMouse = NO;
    if (_didDrag) {
        if (self.finishDrag) self.finishDrag(point);
        [NSCursor.pointingHandCursor set];
    } else {
        [self performClick:self];
    }
}
@end

@implementation EdgeTabController
{
    __weak ItsycalWindow *_calendarWindow;
    EdgeHandlePanel *_tabWindow;
    EdgeHandleButton *_handle;
    EdgeHandleButton *_drawerHandle;
    EdgeHandleButton *_todoHandle, *_drawerTodoHandle;
    NSView *_collapsedStrip, *_expandedStrip;
    NSSize _configuredSize;
    NSUInteger _animationGeneration;
    BOOL _dragging;
    BOOL _transitioning;
    BOOL _dragWasExpanded;
    BOOL _dragRevealing;
    BOOL _dragRevealLeft;
    NSInteger _dragTab;
    NSScreen *_dragRevealScreen;
    CGFloat _dragRevealClosedOffset;
    NSPoint _dragStart;
    NSRect _dragInitialFrame;
}

- (instancetype)initWithCalendarWindow:(ItsycalWindow *)calendarWindow
{
    if ((self = [super init])) {
        _calendarWindow = calendarWindow;
        _tabWindow = [[EdgeHandlePanel alloc] initWithContentRect:NSMakeRect(0, 0, SingleTabSize.width, SingleTabSize.height)
                                                      styleMask:NSWindowStyleMaskBorderless | NSWindowStyleMaskNonactivatingPanel
                                                        backing:NSBackingStoreBuffered defer:NO];
        _tabWindow.title = @"Bar-cal edge tab";
        _tabWindow.backgroundColor = NSColor.clearColor;
        _tabWindow.opaque = NO;
        _tabWindow.hasShadow = NO;
        _tabWindow.hidesOnDeactivate = NO;
        _tabWindow.level = NSFloatingWindowLevel;
        _tabWindow.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorFullScreenAuxiliary;
        _tabWindow.releasedWhenClosed = NO;
        _handle = [[EdgeHandleButton alloc] initWithFrame:NSMakeRect(0, 0, SingleTabSize.width, SingleTabSize.height)];
        _handle.bordered = NO;
        _handle.title = @"";
        _handle.target = self;
        _handle.action = @selector(toggle:);
        _handle.toolTip = NSLocalizedString(@"Click to open or close Bar-cal. Drag to move to either screen edge. Right-click for Settings.", @"");
        _collapsedStrip = [[NSView alloc] initWithFrame:_handle.frame];
        _expandedStrip = [[NSView alloc] initWithFrame:_handle.frame];
        [_collapsedStrip addSubview:_handle];
        _tabWindow.contentView = _collapsedStrip;
        _drawerHandle = [[EdgeHandleButton alloc] initWithFrame:_handle.frame];
        _drawerHandle.bordered = NO;
        _drawerHandle.title = @"";
        _drawerHandle.target = self;
        _drawerHandle.action = @selector(toggle:);
        _drawerHandle.toolTip = _handle.toolTip;
        _handle.tag = BarCalDrawerTabCalendar;
        _drawerHandle.tag = BarCalDrawerTabCalendar;
        [_expandedStrip addSubview:_drawerHandle];
        _todoHandle = [[EdgeHandleButton alloc] initWithFrame:_handle.frame];
        _drawerTodoHandle = [[EdgeHandleButton alloc] initWithFrame:_handle.frame];
        [_collapsedStrip addSubview:_todoHandle];
        [_expandedStrip addSubview:_drawerTodoHandle];
        for (EdgeHandleButton *button in @[_todoHandle, _drawerTodoHandle]) {
            button.bordered = NO;
            button.title = @"";
            button.target = self;
            button.action = @selector(toggle:);
            button.tag = BarCalDrawerTabTodo;
        }
        [calendarWindow setEdgeHandleView:_expandedStrip];

        NSMenu *menu = [NSMenu new];
        NSMenuItem *settings = [menu addItemWithTitle:NSLocalizedString(@"Settings…", @"") action:@selector(openSettings:) keyEquivalent:@""];
        settings.target = self;
        [menu addItem:[NSMenuItem separatorItem]];
        NSMenuItem *quit = [menu addItemWithTitle:NSLocalizedString(@"Quit Bar-cal", @"") action:@selector(terminate:) keyEquivalent:@""];
        quit.target = NSApp;
        _handle.menu = menu;
        _drawerHandle.menu = menu;
        _todoHandle.menu = menu;
        _drawerTodoHandle.menu = menu;

        __weak typeof(self) weakSelf = self;
        for (EdgeHandleButton *handle in @[_handle, _drawerHandle, _todoHandle, _drawerTodoHandle]) {
            BOOL expandedHandle = handle == _drawerHandle || handle == _drawerTodoHandle;
            NSInteger tab = handle.tag;
            handle.beginDrag = ^(NSPoint start) {
                [weakSelf beginDraggingAtPoint:start fromDrawer:expandedHandle tab:tab];
            };
            handle.moveDrag = ^(NSPoint point) {
                [weakSelf moveDraggingToPoint:point];
            };
            handle.finishDrag = ^(NSPoint point) { [weakSelf finishDraggingAtPoint:point]; };
        }
        [self updateTabs];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(displaysChanged:) name:NSApplicationDidChangeScreenParametersNotification object:nil];
    }
    return self;
}

- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; [_tabWindow orderOut:nil]; }

- (NSScreen *)screen
{
    NSNumber *display = [NSUserDefaults.standardUserDefaults objectForKey:kEdgeTabDisplay];
    for (NSScreen *screen in NSScreen.screens) {
        if ([screen.deviceDescription[@"NSScreenNumber"] isEqual:display]) return screen;
    }
    return NSScreen.mainScreen ?: NSScreen.screens.firstObject;
}

- (BOOL)isLeft { return [NSUserDefaults.standardUserDefaults integerForKey:kScreenEdge] == BarCalScreenEdgeLeft; }
- (BOOL)tabsEnabled { return [NSUserDefaults.standardUserDefaults boolForKey:kDrawerTabsEnabled]; }
- (NSSize)tabSize { return self.tabsEnabled ? BrowserTabsSize : SingleTabSize; }
- (NSRect)collapsedTabFrame
{
    return BarCalEdgeTabFrame(self.screen.visibleFrame, self.isLeft, [NSUserDefaults.standardUserDefaults doubleForKey:kEdgeTabPosition], self.tabSize);
}
- (NSRect)drawerFrame
{
    return BarCalEdgeDrawerFrameAtAnchor(self.screen.visibleFrame, self.collapsedTabFrame, self.isLeft,
                                        _calendarWindow.frame.size, [NSUserDefaults.standardUserDefaults doubleForKey:kEdgeTabAnchor]);
}
- (NSRect)expandedTabFrame
{
    NSRect body = self.drawerFrame;
    body.size.width -= self.tabSize.width - 1;
    if (!self.isLeft) body.origin.x += self.tabSize.width - 1;
    return BarCalEdgeAttachedTabFrame(body, self.collapsedTabFrame, self.isLeft);
}

- (void)setEnabled:(BOOL)enabled
{
    _calendarWindow.screenEdgeOnLeft = self.isLeft;
    if (_enabled == enabled) { if (enabled) [self updatePlacement]; return; }
    _enabled = enabled;
    [self hideCalendarAnimated:NO];
    _calendarWindow.screenEdgeMode = enabled;
    _calendarWindow.level = enabled ? NSFloatingWindowLevel : NSMainMenuWindowLevel;
    _calendarWindow.collectionBehavior = enabled ? NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorFullScreenAuxiliary : NSWindowCollectionBehaviorMoveToActiveSpace;
    _calendarWindow.animationBehavior = enabled ? NSWindowAnimationBehaviorNone : NSWindowAnimationBehaviorUtilityWindow;
    _calendarWindow.hasShadow = YES;
    if (enabled) {
        NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
        if (![defaults objectForKey:kEdgeTabDisplay]) {
            [defaults setObject:self.screen.deviceDescription[@"NSScreenNumber"] forKey:kEdgeTabDisplay];
        }
        [self updatePlacement];
        [_tabWindow orderFrontRegardless];
    } else {
        [_tabWindow orderOut:nil];
    }
}

- (void)toggle:(NSButton *)sender
{
    NSInteger selected = [NSUserDefaults.standardUserDefaults integerForKey:kSelectedDrawerTab];
    if (self.tabsEnabled && (!self.expanded || sender.tag != selected)) {
        if (self.selectTab) self.selectTab(sender.tag);
        if (!self.expanded && self.toggleCalendar) self.toggleCalendar();
    } else if (self.toggleCalendar) self.toggleCalendar();
}
- (void)openSettings:(id)sender { if (self.showSettings) self.showSettings(); }
- (NSTimeInterval)animationDuration { return NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion ? 0 : 0.3; }

- (CGFloat)collapsedOffset
{
    return NSMinX(self.collapsedTabFrame) - NSMinX(self.expandedTabFrame);
}

- (void)restoreCollapsedTab
{
    [_tabWindow setFrame:self.collapsedTabFrame display:YES];
    if (self.enabled) [_tabWindow orderFrontRegardless];
}

- (void)animateRevealTo:(CGFloat)offset generation:(NSUInteger)generation
{
    CGFloat distance = fabs(offset - _calendarWindow.edgeRevealOffset);
    NSTimeInterval duration = self.animationDuration * MIN(1, distance / MAX(1, fabs(self.collapsedOffset)));
    [_calendarWindow animateEdgeRevealTo:offset duration:duration completion:^{
        if (generation != self->_animationGeneration) return;
        self->_transitioning = NO;
        if (self->_expanded) {
            [self updatePlacement];
            self->_calendarWindow.hasShadow = YES;
            [self->_calendarWindow invalidateShadow];
        } else {
            [self->_calendarWindow orderOut:nil];
            [self->_calendarWindow setEdgeRevealOffset:0];
            [self restoreCollapsedTab];
        }
    }];
}

- (void)showCalendar
{
    if (!self.enabled) return;
    if (_expanded && !_transitioning) { [_calendarWindow makeKeyAndOrderFront:nil]; return; }
    NSUInteger generation = ++_animationGeneration;
    BOOL reversing = _transitioning && _calendarWindow.isVisible;
    _expanded = YES;
    _transitioning = YES;
    [self updateHandle];
    if (reversing) {
        [self animateRevealTo:0 generation:generation];
        return;
    }
    // Let pending agenda sizing finish before capturing the final geometry.
    dispatch_async(dispatch_get_main_queue(), ^{
        if (generation != self->_animationGeneration || !self->_expanded) return;
        [self->_calendarWindow.contentView layoutSubtreeIfNeeded];
        self->_transitioning = NO;
        [self updatePlacement];
        self->_transitioning = YES;
        self->_calendarWindow.hasShadow = NO;
        [self->_calendarWindow setEdgeRevealOffset:self.collapsedOffset];
        [self->_calendarWindow makeKeyAndOrderFront:nil];
        [self->_calendarWindow displayIfNeeded];
        [self->_tabWindow orderOut:nil];
        [self animateRevealTo:0 generation:generation];
    });
}

- (void)hideCalendarAnimated:(BOOL)animated
{
    // Changing key windows during a drag must not replace the moving drawer
    // with the collapsed handle. The gesture owns its presentation until up.
    if (_dragging) return;
    if (!_expanded && _transitioning && animated) return;
    NSUInteger generation = ++_animationGeneration;
    _expanded = NO;
    [self updateHandle];
    if (!_calendarWindow.isVisible || !animated || self.animationDuration == 0) {
        _transitioning = NO;
        [_calendarWindow setEdgeRevealOffset:0];
        [_calendarWindow orderOut:nil];
        [self restoreCollapsedTab];
        return;
    }
    _transitioning = YES;
    _calendarWindow.hasShadow = NO;
    [self animateRevealTo:self.collapsedOffset generation:generation];
}

- (void)updateHandle
{
    _handle.expanded = NO;
    _drawerHandle.expanded = YES;
    _drawerTodoHandle.expanded = YES;
    NSInteger selected = [NSUserDefaults.standardUserDefaults integerForKey:kSelectedDrawerTab];
    for (EdgeHandleButton *handle in @[_handle, _drawerHandle, _todoHandle, _drawerTodoHandle]) {
        handle.attachedOnLeft = self.isLeft;
        BOOL todo = handle.tag == BarCalDrawerTabTodo;
        handle.selected = selected == handle.tag;
        handle.displayTitle = self.tabsEnabled ? (todo ? NSLocalizedString(@"To-do", @"") : NSLocalizedString(@"Cal", @"Short Calendar tab label")) : @"";
        handle.accessibilityLabel = self.tabsEnabled ? (todo ? NSLocalizedString(@"To-do tab", @"") : NSLocalizedString(@"Calendar tab", @""))
            : (handle.expanded ? NSLocalizedString(@"Hide Bar-cal calendar", @"") : NSLocalizedString(@"Show Bar-cal calendar", @""));
        handle.accessibilityValue = @(handle.selected);
        handle.toolTip = self.tabsEnabled ? NSLocalizedString(@"Click to select a tab. Click the active tab to close. Drag either tab to move. Right-click for Settings.", @"")
            : NSLocalizedString(@"Click to open or close Bar-cal. Drag to move to either screen edge. Right-click for Settings.", @"");
        [handle setNeedsDisplay:YES];
    }
}

- (void)updateTabs
{
    NSSize size = self.tabSize;
    if (!NSEqualSizes(size, _configuredSize)) {
        ++_animationGeneration;
        _transitioning = NO;
        [_calendarWindow setEdgeRevealOffset:0];
        _configuredSize = size;
        [_tabWindow setContentSize:size];
        _collapsedStrip.frame = NSMakeRect(0, 0, size.width, size.height);
        _expandedStrip.frame = _collapsedStrip.frame;
        for (EdgeHandleButton *button in @[_handle, _drawerHandle]) button.frame = NSMakeRect(0, self.tabsEnabled ? 54 : 0, size.width, self.tabsEnabled ? 50 : 58);
        for (EdgeHandleButton *button in @[_todoHandle, _drawerTodoHandle]) {
            button.frame = NSMakeRect(0, 0, size.width, 50);
            button.hidden = !self.tabsEnabled;
        }
        [_calendarWindow setEdgeHandleView:_expandedStrip];
        [_calendarWindow.contentView layoutSubtreeIfNeeded];
    }
    [self updateHandle];
    [self updatePlacement];
}

- (void)updatePlacement
{
    if (!self.enabled || _dragging || _transitioning) return;
    if (self.expanded) [_calendarWindow setFrame:self.drawerFrame display:YES];
    [_calendarWindow setEdgeHandleFrame:[_calendarWindow convertRectFromScreen:self.expandedTabFrame]];
    if (!self.expanded) [_tabWindow setFrame:self.collapsedTabFrame display:YES];
    [self updateHandle];
}

- (void)beginDraggingAtPoint:(NSPoint)point fromDrawer:(BOOL)fromDrawer tab:(NSInteger)tab
{
    _dragging = YES;
    _dragWasExpanded = fromDrawer && _calendarWindow.isVisible;
    _dragRevealing = NO;
    _dragTab = tab;
    os_log_info(EdgeDragLog(), "Drag began; expanded=%{public}d", _dragWasExpanded);
    _dragStart = point;
    ++_animationGeneration;
    _transitioning = NO;
    if (_dragWasExpanded) {
        // Freeze a reveal at its actual visible position before moving the
        // window, so grabbing a moving notch never resets it to its endpoint.
        CGFloat offset = _calendarWindow.edgeRevealOffset;
        [_calendarWindow setEdgeRevealOffset:0];
        _dragInitialFrame = NSOffsetRect(_calendarWindow.frame, offset, 0);
        [_calendarWindow setFrame:_dragInitialFrame display:YES];
        _calendarWindow.hasShadow = YES;
        _expanded = YES;
        [_tabWindow orderOut:nil];
    } else {
        _dragInitialFrame = _tabWindow.frame;
    }
}

- (void)beginInteractiveReveal
{
    _dragRevealing = YES;
    _dragRevealScreen = self.screen;
    _dragRevealLeft = self.isLeft;
    _expanded = YES;
    if (self.tabsEnabled && self.selectTab) self.selectTab(_dragTab);
    [self updateHandle];
    [_calendarWindow.contentView layoutSubtreeIfNeeded];
    NSRect target = BarCalEdgeDrawerFrameAtAnchor(_dragRevealScreen.visibleFrame, _dragInitialFrame, _dragRevealLeft,
        _calendarWindow.frame.size, [NSUserDefaults.standardUserDefaults doubleForKey:kEdgeTabAnchor]);
    [_calendarWindow setFrame:target display:NO];
    NSRect body = target;
    body.size.width -= self.tabSize.width - 1;
    if (!_dragRevealLeft) body.origin.x += self.tabSize.width - 1;
    NSRect attached = BarCalEdgeAttachedTabFrame(body, _dragInitialFrame, _dragRevealLeft);
    _dragRevealClosedOffset = NSMinX(_dragInitialFrame) - NSMinX(attached);
    [_calendarWindow setEdgeHandleFrame:[_calendarWindow convertRectFromScreen:attached]];
    [_calendarWindow setEdgeRevealOffset:_dragRevealClosedOffset];
    _calendarWindow.hasShadow = NO;
    [_calendarWindow makeKeyAndOrderFront:nil];
    // Keep the original input window alive until mouse-up. It overlays the
    // identical live notch, preserving AppKit's drag capture as content appears.
    [_tabWindow orderFrontRegardless];
    os_log_info(EdgeDragLog(), "Interactive reveal began; left=%{public}d", _dragRevealLeft);
}

- (void)moveInteractiveRevealToPoint:(NSPoint)point
{
    NSRect desiredTab = BarCalEdgeDraggedFrame(_dragInitialFrame, _dragStart, point);
    NSRect bottom = BarCalEdgeTabFrame(_dragRevealScreen.visibleFrame, _dragRevealLeft, 0, self.tabSize);
    NSRect top = BarCalEdgeTabFrame(_dragRevealScreen.visibleFrame, _dragRevealLeft, 1, self.tabSize);
    desiredTab.origin.y = MIN(MAX(NSMinY(desiredTab), NSMinY(bottom)), NSMinY(top));
    NSRect target = BarCalEdgeDrawerFrameAtAnchor(_dragRevealScreen.visibleFrame, desiredTab, _dragRevealLeft,
        _calendarWindow.frame.size, [NSUserDefaults.standardUserDefaults doubleForKey:kEdgeTabAnchor]);
    [_calendarWindow setFrame:target display:YES];
    NSRect body = target;
    body.size.width -= self.tabSize.width - 1;
    if (!_dragRevealLeft) body.origin.x += self.tabSize.width - 1;
    NSRect attached = BarCalEdgeAttachedTabFrame(body, desiredTab, _dragRevealLeft);
    CGFloat offset = BarCalEdgePullOffset(_dragRevealClosedOffset, point.x - _dragStart.x);
    [_calendarWindow setEdgeHandleFrame:[_calendarWindow convertRectFromScreen:attached]];
    [_calendarWindow setEdgeRevealOffset:offset];
    [_tabWindow setFrame:NSOffsetRect(attached, offset, 0) display:YES];
}

- (void)moveDraggingToPoint:(NSPoint)point
{
    if (!_dragging) return;
    CGFloat inward = (self.isLeft ? 1 : -1) * (point.x - _dragStart.x);
    if (!_dragWasExpanded && !_dragRevealing && inward > 4) [self beginInteractiveReveal];
    if (_dragRevealing) { [self moveInteractiveRevealToPoint:point]; return; }
    NSRect frame = BarCalEdgeDraggedFrame(_dragInitialFrame, _dragStart, point);
    NSWindow *window = _dragWasExpanded ? _calendarWindow : _tabWindow;
    [window setFrame:frame display:YES];
}

- (void)finishDraggingAtPoint:(NSPoint)point
{
    if (!_dragging) return;
    [self moveDraggingToPoint:point];
    BOOL revealed = _dragRevealing;
    BOOL drawerDrag = _dragWasExpanded || revealed;
    CGFloat progress = revealed ? BarCalEdgePullProgress(_dragRevealClosedOffset, _calendarWindow.edgeRevealOffset) : 0;
    NSScreen *screen = revealed ? _dragRevealScreen : self.screen;
    if (!revealed) for (NSScreen *candidate in NSScreen.screens) if (NSPointInRect(point, candidate.frame)) { screen = candidate; break; }
    NSRect dragged = drawerDrag ? _calendarWindow.frame : _tabWindow.frame;
    NSRect notch = _tabWindow.frame;
    if (drawerDrag) {
        // Keep the original notch-to-panel offset on drop. Re-centering the
        // panel around its notch would otherwise cause a second vertical jump.
        CGFloat minY = NSMinY(screen.visibleFrame) + 8;
        CGFloat maxY = MAX(minY, NSMaxY(screen.visibleFrame) - NSHeight(dragged) - 8);
        dragged.origin.y = MIN(MAX(NSMinY(dragged), minY), maxY);
        [_calendarWindow setFrame:dragged display:YES];
        notch = [_calendarWindow convertRectToScreen:[_expandedStrip convertRect:_expandedStrip.bounds toView:nil]];
    }
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    [defaults setObject:screen.deviceDescription[@"NSScreenNumber"] forKey:kEdgeTabDisplay];
    if (drawerDrag) {
        [defaults setDouble:(NSMidY(notch) - NSMinY(dragged)) / MAX(1, NSHeight(dragged)) forKey:kEdgeTabAnchor];
    }
    NSRect bottom = BarCalEdgeTabFrame(screen.visibleFrame, YES, 0, self.tabSize);
    NSRect top = BarCalEdgeTabFrame(screen.visibleFrame, YES, 1, self.tabSize);
    CGFloat travel = MAX(1, NSMinY(top) - NSMinY(bottom));
    [defaults setDouble:MIN(MAX((NSMinY(notch) - NSMinY(bottom)) / travel, 0), 1) forKey:kEdgeTabPosition];
    BOOL left = revealed ? _dragRevealLeft : NSMidX(dragged) < NSMidX(screen.visibleFrame);
    [defaults setInteger:left ? BarCalScreenEdgeLeft : BarCalScreenEdgeRight forKey:kScreenEdge];
    _dragging = NO;
    _dragRevealing = NO;
    _dragRevealScreen = nil;
    if (revealed) {
        _expanded = progress >= 0.25;
        _transitioning = YES;
        [_tabWindow orderOut:nil];
        [self updateHandle];
        [self animateRevealTo:_expanded ? 0 : self.collapsedOffset generation:++_animationGeneration];
        os_log_info(EdgeDragLog(), "Interactive reveal released; progress=%{public}.2f, open=%{public}d", progress, _expanded);
    } else [self updatePlacement];
    os_log_info(EdgeDragLog(), "Drag finished; expanded=%{public}d, left=%{public}d", self.expanded, self.isLeft);
}

- (void)displaysChanged:(NSNotification *)notification { [self updatePlacement]; }
@end
