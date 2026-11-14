#import <Cocoa/Cocoa.h>
@class ItsycalWindow;

// Owns the handle panel; the existing calendar controller keeps ownership of
// calendar content, keyboard commands, data and settings.
@interface EdgeTabController : NSObject
@property (nonatomic, copy) void (^toggleCalendar)(void);
@property (nonatomic, copy) void (^showSettings)(void);
@property (nonatomic, copy) void (^selectTab)(NSInteger tab);
@property (nonatomic, getter=isEnabled) BOOL enabled;
@property (nonatomic, readonly, getter=isExpanded) BOOL expanded;
@property (nonatomic, readonly) NSScreen *screen;
- (instancetype)initWithCalendarWindow:(ItsycalWindow *)calendarWindow;
- (void)showCalendar;
- (void)hideCalendarAnimated:(BOOL)animated;
- (void)updatePlacement;
- (void)updateTabs;
@end
