//
//  ItsycalWindow.m
//  Itsycal
//
//  Created by Sanjay Madan on 12/14/14.
//  Copyright (c) 2014 mowglii.com. All rights reserved.
//

#import "ItsycalWindow.h"
#import <QuartzCore/QuartzCore.h>
#import "Themer.h"

static const CGFloat kMinimumSpaceBetweenWindowAndScreenEdge = 10;
static const CGFloat kArrowHeight  = 8;
static const CGFloat kCornerRadius = 16;
static const CGFloat kVerticalPadding = 11;

@interface ItsycalWindowFrameView : NSView
@property (nonatomic, assign) CGFloat arrowMidX;
@property (nonatomic) BOOL drawsArrow;
@end

#pragma mark -
#pragma mark ItsycalWindow

// =========================================================================
// ItsycalWindow
// =========================================================================

@implementation ItsycalWindow
{
    NSView *_slidingContent;
    ItsycalWindowFrameView *_calendarFrame;
    NSView *_edgeHandle;
    NSLayoutConstraint *_bodyLeading;
    NSLayoutConstraint *_bodyTrailing;
}

- (id)init
{
    self = [super initWithContentRect:NSZeroRect styleMask:NSWindowStyleMaskNonactivatingPanel backing:NSBackingStoreBuffered defer:NO];
    if (self) {
        [self setBackgroundColor:[NSColor clearColor]];
        [self setOpaque:NO];
        [self setLevel:NSMainMenuWindowLevel];
        [self setMovableByWindowBackground:NO];
        [self setCollectionBehavior:NSWindowCollectionBehaviorMoveToActiveSpace];
        // Fade out when -[NSWindow orderOut:] is called.
        [self setAnimationBehavior:NSWindowAnimationBehaviorUtilityWindow];
        // The stationary host clips a single moving surface to this display.
        // Calendar and notch share one compositor animation, with no per-frame
        // window movement or Auto Layout work.
        NSView *host = [NSView new];
        host.wantsLayer = YES;
        _slidingContent = [NSView new];
        _slidingContent.translatesAutoresizingMaskIntoConstraints = NO;
        _slidingContent.wantsLayer = YES;
        [host addSubview:_slidingContent];
        _calendarFrame = [ItsycalWindowFrameView new];
        _calendarFrame.translatesAutoresizingMaskIntoConstraints = NO;
        [_slidingContent addSubview:_calendarFrame];
        _bodyLeading = [_calendarFrame.leadingAnchor constraintEqualToAnchor:_slidingContent.leadingAnchor];
        _bodyTrailing = [_calendarFrame.trailingAnchor constraintEqualToAnchor:_slidingContent.trailingAnchor];
        [NSLayoutConstraint activateConstraints:@[
            [_slidingContent.leadingAnchor constraintEqualToAnchor:host.leadingAnchor],
            [_slidingContent.trailingAnchor constraintEqualToAnchor:host.trailingAnchor],
            [_slidingContent.topAnchor constraintEqualToAnchor:host.topAnchor],
            [_slidingContent.bottomAnchor constraintEqualToAnchor:host.bottomAnchor],
            _bodyLeading, _bodyTrailing,
            [_calendarFrame.topAnchor constraintEqualToAnchor:_slidingContent.topAnchor],
            [_calendarFrame.bottomAnchor constraintEqualToAnchor:_slidingContent.bottomAnchor],
        ]];
        self.contentView = host;
    }
    return self;
}

- (BOOL)canBecomeMainWindow
{
    return NO;
}

- (void)setScreenEdgeMode:(BOOL)screenEdgeMode
{
    _screenEdgeMode = screenEdgeMode;
    _calendarFrame.drawsArrow = !screenEdgeMode;
    _calendarFrame.additionalSafeAreaInsets = NSEdgeInsetsMake(kVerticalPadding + (screenEdgeMode ? 0 : kArrowHeight), 0, kVerticalPadding, 0);
    self.contentView.layer.masksToBounds = screenEdgeMode;
    _edgeHandle.hidden = !screenEdgeMode;
    [self updateEdgeInsets];
    [_calendarFrame setNeedsLayout:YES];
}

- (NSView *)calendarContentView { return _calendarFrame; }

- (void)setScreenEdgeOnLeft:(BOOL)screenEdgeOnLeft
{
    _screenEdgeOnLeft = screenEdgeOnLeft;
    [self updateEdgeInsets];
}

- (void)updateEdgeInsets
{
    CGFloat inset = MAX(0, NSWidth(_edgeHandle.frame) - 1);
    _bodyLeading.constant = self.screenEdgeMode && !self.screenEdgeOnLeft ? inset : 0;
    _bodyTrailing.constant = self.screenEdgeMode && self.screenEdgeOnLeft ? -inset : 0;
}

- (void)setEdgeHandleView:(NSView *)view
{
    [_edgeHandle removeFromSuperview];
    _edgeHandle = view;
    [_slidingContent addSubview:view positioned:NSWindowAbove relativeTo:_calendarFrame];
    view.hidden = !self.screenEdgeMode;
    [self updateEdgeInsets];
}

- (void)setEdgeHandleFrame:(NSRect)frame { _edgeHandle.frame = frame; }

- (CGFloat)edgeRevealOffset
{
    // A hidden window can retain an old presentation layer. Only consult it
    // while an animation is active; a fresh reveal starts at its model offset.
    CABasicAnimation *slide = (CABasicAnimation *)[_slidingContent.layer animationForKey:@"EdgeReveal"];
    if (slide) {
        CALayer *visible = _slidingContent.layer.presentationLayer;
        return visible ? visible.transform.m41 : [slide.fromValue doubleValue];
    }
    return _slidingContent.layer.transform.m41;
}

- (void)setEdgeRevealOffset:(CGFloat)offset
{
    [_slidingContent.layer removeAnimationForKey:@"EdgeReveal"];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _slidingContent.layer.transform = CATransform3DMakeTranslation(offset, 0, 0);
    [CATransaction commit];
}

- (void)animateEdgeRevealTo:(CGFloat)offset duration:(NSTimeInterval)duration completion:(void (^)(void))completion
{
    CGFloat current = self.edgeRevealOffset;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    [CATransaction setCompletionBlock:completion];
    _slidingContent.layer.transform = CATransform3DMakeTranslation(offset, 0, 0);
    if (duration > 0) {
        CABasicAnimation *slide = [CABasicAnimation animationWithKeyPath:@"transform.translation.x"];
        slide.fromValue = @(current);
        slide.toValue = @(offset);
        slide.duration = duration;
        slide.timingFunction = [CAMediaTimingFunction functionWithControlPoints:0.22 :1 :0.36 :1];
        [_slidingContent.layer addAnimation:slide forKey:@"EdgeReveal"];
    } else {
        [_slidingContent.layer removeAnimationForKey:@"EdgeReveal"];
    }
    [CATransaction commit];
}

- (BOOL)canBecomeKeyWindow
{
    return YES;
}

- (void)sendEvent:(NSEvent *)event
{
    // When Itsycal is pinned and the user clicks in another app,
    // our window resigns key. AppKit then uses the next click in
    // our window to make it key and swallows that click unless the
    // view under it accepts first mouse. Become key first so the
    // click goes through to whatever view the user clicked.
    if (event.type == NSEventTypeLeftMouseDown && !self.isKeyWindow) {
        [self makeKeyWindow];
    }
    [super sendEvent:event];
}

- (void)positionRelativeToRect:(NSRect)rect screenMaxX:(CGFloat)screenMaxX
{
    // Calculate window's top left point.
    // First, center window under status item.
    CGFloat w = NSWidth(self.frame);
    CGFloat x = roundf(NSMidX(rect) - w / 2);
    CGFloat y = NSMinY(rect) - 2;
    
    // If the calculated x position puts the window too
    // far to the right, shift the window left.
    if (x + w + kMinimumSpaceBetweenWindowAndScreenEdge > screenMaxX) {
        x = screenMaxX - w - kMinimumSpaceBetweenWindowAndScreenEdge;
    }

    // Set the window position.
    [self setFrameTopLeftPoint:NSMakePoint(x, y)];

    // Tell the frame view where to draw the arrow.
    _calendarFrame.arrowMidX = NSMidX([self convertRectFromScreen:rect]);
    
    [self invalidateShadow];
}

@end

#pragma mark -
#pragma mark ItsycalWindowFrameView

// =========================================================================
// ItsycalWindowFrameView
// =========================================================================

@implementation ItsycalWindowFrameView
{
    CALayer *_bodyMask;
    CAShapeLayer *_arrowMask;
    CALayer *_bodyBorder;
}

- (instancetype)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self) {
        self.wantsLayer = YES;
        _drawsArrow = YES;
        self.additionalSafeAreaInsets = NSEdgeInsetsMake(kArrowHeight + kVerticalPadding, 0, kVerticalPadding, 0);

        // The window's shape is a rounded body with a little arrow at
        // the top. Masking our layer to that shape clips our background
        // and the content's corners. Masks use only alpha, so any opaque
        // color works.
        _bodyMask = [CALayer layer];
        _bodyMask.backgroundColor = NSColor.blackColor.CGColor;
        _bodyMask.cornerRadius = kCornerRadius;
        _bodyMask.cornerCurve = kCACornerCurveContinuous;
        _arrowMask = [CAShapeLayer layer];
        _arrowMask.fillColor = NSColor.blackColor.CGColor;
        [_bodyMask addSublayer:_arrowMask];
        self.layer.mask = _bodyMask;
        _bodyBorder = [CALayer layer];
        _bodyBorder.cornerRadius = kCornerRadius;
        _bodyBorder.cornerCurve = kCACornerCurveContinuous;
        [self.layer addSublayer:_bodyBorder];
    }
    return self;
}

- (void)setArrowMidX:(CGFloat)arrowMidX
{
    _arrowMidX = arrowMidX;
    [self updateMask];
}

- (void)layout
{
    [super layout];
    [self updateMask];
}

- (BOOL)wantsUpdateLayer
{
    return YES;
}

- (void)updateLayer
{
    self.layer.backgroundColor = Theme.mainBackgroundColor.CGColor;
    _bodyBorder.borderWidth = Theme.themePreference == ThemePreferenceSlate ? 0.5 : 0;
    _bodyBorder.borderColor = [NSColor colorWithWhite:0.43 alpha:1].CGColor;
}

- (void)updateMask
{
    [CATransaction begin];
    [CATransaction setDisableActions:YES];

    NSRect bodyRect = self.bounds;
    bodyRect.size.height -= self.drawsArrow ? kArrowHeight : 0;
    _bodyMask.frame = bodyRect;
    _bodyBorder.frame = NSInsetRect(bodyRect, 0.25, 0.25);

    // Add the arrow to the body if its right edge is inside
    // the right edge of the body (taking into account the corner
    // radius). This accounts for the edge-case where Itsycal is
    // all the way to the right in the menu bar. This is possible
    // if the user has a 3rd party app like Bartender.
    // The arrow is in _bodyMask's coordinates, whose origin is the
    // bottom left of the body. Its base extends 1pt into the body so
    // no seam shows where they meet.
    CGFloat curveOffset = 5;
    CGFloat arrowMidX = (_arrowMidX == 0) ? NSMidX(self.bounds) : _arrowMidX;
    CGFloat arrowRightEdge = arrowMidX + curveOffset + kArrowHeight;
    CGFloat bodyRightEdge = NSMaxX(bodyRect) - kCornerRadius;
    NSBezierPath *arrowPath = [NSBezierPath bezierPath];
    if (self.drawsArrow && arrowRightEdge < bodyRightEdge) {
        CGFloat x = arrowMidX - kArrowHeight - curveOffset;
        CGFloat y = NSHeight(bodyRect);
        [arrowPath moveToPoint:NSMakePoint(x, y)];
        [arrowPath relativeCurveToPoint:NSMakePoint(kArrowHeight + curveOffset, kArrowHeight) controlPoint1:NSMakePoint(curveOffset, 0) controlPoint2:NSMakePoint(kArrowHeight, kArrowHeight)];
        [arrowPath relativeCurveToPoint:NSMakePoint(kArrowHeight + curveOffset, -kArrowHeight) controlPoint1:NSMakePoint(curveOffset, 0) controlPoint2:NSMakePoint(kArrowHeight, -kArrowHeight)];
        [arrowPath relativeLineToPoint:NSMakePoint(0, -1)];
        [arrowPath lineToPoint:NSMakePoint(x, y - 1)];
        [arrowPath closePath];
    }
    _arrowMask.path = arrowPath.CGPath;

    [CATransaction commit];
}

@end
