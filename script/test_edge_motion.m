#import <Cocoa/Cocoa.h>
#import "ItsycalWindow.h"
#import "Themer.h"

// This hidden-window test needs no application theme or calendar access.
Themer *Theme = nil;

static void Expect(BOOL condition, NSString *message)
{
    if (!condition) { NSLog(@"FAIL: %@", message); exit(1); }
}

int main(void)
{
    @autoreleasepool {
        [NSApplication sharedApplication];
        ItsycalWindow *window = [ItsycalWindow new];
        [window setContentSize:NSMakeSize(240, 400)];
        window.screenEdgeMode = YES;
        NSRect stationary = window.frame;

        for (NSNumber *side in @[@(-1), @1]) {
            CGFloat closed = side.doubleValue * 177;
            [window setEdgeRevealOffset:closed];
            Expect(window.edgeRevealOffset == closed, @"A fresh reveal starts at the collapsed position");
            [window animateEdgeRevealTo:0 duration:0.3 completion:nil];
            // Reversing before the first rendered frame must use the start
            // position, rather than the animation's final model value.
            Expect(window.edgeRevealOffset == closed, @"A same-frame interruption preserves the visible start position");
            [window animateEdgeRevealTo:closed duration:0.3 completion:nil];
            Expect(window.edgeRevealOffset == closed, @"An immediate reversal never teleports to the open position");
            [window setEdgeRevealOffset:closed / 2];
            Expect(window.edgeRevealOffset == closed / 2, @"Cancelling an animation replaces its old position");
            [window animateEdgeRevealTo:0 duration:0 completion:nil];
            Expect(window.edgeRevealOffset == 0, @"Reduced motion reaches the open state immediately");
            Expect(NSEqualRects(window.frame, stationary), @"Revealing content never moves or resizes its host window");
        }
        Expect(!window.isVisible, @"Motion checks never present a window");
        NSLog(@"PASS: reveal continuity, immediate reversal, cancellation, reduced motion, and stationary host");
    }
    return 0;
}
