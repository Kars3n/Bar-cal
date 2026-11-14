#import <Cocoa/Cocoa.h>
@class EventCenter;

@interface TodoViewController : NSViewController <NSTableViewDataSource, NSTableViewDelegate>
@property (nonatomic, weak) EventCenter *eventCenter;
@property (nonatomic) BOOL active;
@property (nonatomic, copy) void (^showSettings)(void);
- (void)reload;
@end
