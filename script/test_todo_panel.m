#import <Cocoa/Cocoa.h>
#import "TodoViewController.h"
#import "EventCenter.h"
#import "TodoOrdering.h"
#import "Itsycal.h"
#import "Themer.h"
#import "Sizer.h"

// Test doubles deliberately avoid constructing an EKEventStore. No account
// access, permission prompt, real reminder write, or visible window is used.
Themer *Theme = nil;

@interface TestList : NSObject
@property NSString *calendarIdentifier;
@property NSString *title;
@property id source;
@property EKEntityMask allowedEntityTypes;
@property BOOL allowsContentModifications;
@end
@implementation TestList @end

@interface TestReminder : NSObject
@property NSString *calendarItemIdentifier;
@property NSString *title;
@property id calendar;
@property (getter=isCompleted) BOOL completed;
@end
@implementation TestReminder @end

@interface TestTodoSource : EventCenter
@property NSArray *testLists;
@property NSMutableArray *pending;
@property EKAuthorizationStatus testStatus;
@property NSString *writtenIdentifier;
@property NSUInteger writes;
@end
@implementation TestTodoSource
- (NSArray *)sourcesAndCalendars { return self.testLists; }
- (EKAuthorizationStatus)remindersAuthorizationStatus { return self.testStatus; }
- (void)fetchTodoList:(NSString *)identifier completion:(void (^)(NSArray<EventInfo *> *, NSError *))completion
{
    [self.pending addObject:[completion copy]];
}
- (BOOL)setReminder:(EKReminder *)reminder completed:(BOOL)completed undoManager:(NSUndoManager *)undoManager error:(NSError **)error
{
    self.writtenIdentifier = reminder.calendarItemIdentifier;
    self.writes++;
    reminder.completed = completed;
    return YES;
}
@end

static void Expect(BOOL condition, NSString *message)
{
    if (!condition) { NSLog(@"FAIL: %@", message); exit(1); }
}

static CalendarInfo *List(NSString *identifier)
{
    TestList *list = [TestList new];
    list.calendarIdentifier = identifier;
    list.title = identifier;
    list.source = list;
    list.allowedEntityTypes = EKEntityMaskReminder;
    list.allowsContentModifications = YES;
    CalendarInfo *info = [CalendarInfo new];
    info.calendar = (EKCalendar *)list;
    return info;
}

static EventInfo *Task(CalendarInfo *list, NSString *identifier)
{
    TestReminder *reminder = [TestReminder new];
    reminder.calendarItemIdentifier = identifier;
    reminder.title = @"Test task with no due date";
    reminder.calendar = list.calendar;
    EventInfo *info = [EventInfo new];
    info.reminder = (EKReminder *)reminder;
    return info;
}

int main(void)
{
    @autoreleasepool {
        [NSApplication sharedApplication];
        [Sizer shared];
        NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
        id previous = [defaults objectForKey:kTodoListIdentifier];
        CalendarInfo *a = List(@"fixture-A"), *b = List(@"fixture-B");
        TestTodoSource *source = [TestTodoSource new];
        source.testLists = @[a, b];
        source.testStatus = EKAuthorizationStatusFullAccess;
        source.pending = [NSMutableArray new];
        TodoViewController *panel = [TodoViewController new];
        panel.eventCenter = source;
        (void)panel.view;
        [defaults setObject:@"fixture-A" forKey:kTodoListIdentifier];
        panel.active = YES;
        [defaults setObject:@"fixture-B" forKey:kTodoListIdentifier];
        [panel reload];
        Expect(source.pending.count == 2, @"Switching lists requests each selected list independently");
        void (^oldResult)(NSArray *, NSError *) = source.pending[0];
        void (^newResult)(NSArray *, NSError *) = source.pending[1];
        oldResult(@[Task(a, @"old-task")], nil);
        NSTableView *table = [panel valueForKey:@"table"];
        Expect(table.numberOfRows == 0, @"A stale result from the previous list is ignored");
        EventInfo *task = Task(b, @"current-task");
        newResult(@[task], nil);
        Expect(table.numberOfRows == 1, @"Undated incomplete tasks appear in the selected list");
        NSView *row = [panel tableView:table viewForTableColumn:table.tableColumns.firstObject row:0];
        NSTextField *due = [row valueForKey:@"dueLabel"];
        Expect([due.stringValue isEqualToString:@"No due date"], @"Undated rows have clear metadata");
        NSButton *checkbox = [row valueForKey:@"complete"];
        [checkbox performClick:nil];
        Expect(source.writes == 1 && [source.writtenIdentifier isEqualToString:@"current-task"] && task.reminder.isCompleted,
               @"Completing a row writes only that reminder through the shared source");
        void (^completedResult)(NSArray *, NSError *) = source.pending.lastObject;
        completedResult(@[], nil);
        Expect(table.numberOfRows == 0 && [[[panel valueForKey:@"message"] stringValue] isEqualToString:@"All caught up"],
               @"The list refreshes to its empty state after completion");
        ((TestList *)b.calendar).allowsContentModifications = NO;
        [panel reload];
        void (^readOnlyResult)(NSArray *, NSError *) = source.pending.lastObject;
        readOnlyResult(@[Task(b, @"read-only")], nil);
        row = [panel tableView:table viewForTableColumn:table.tableColumns.firstObject row:0];
        Expect(![[row valueForKey:@"complete"] isEnabled], @"Read-only reminder lists cannot be changed");
        [defaults setObject:@"deleted-list" forKey:kTodoListIdentifier];
        NSUInteger fetches = source.pending.count;
        [panel reload];
        Expect(source.pending.count == fetches && table.numberOfRows == 0,
               @"A deleted selection never silently fetches another list");
        source.testStatus = EKAuthorizationStatusNotDetermined;
        [panel reload];
        Expect(![[panel valueForKey:@"accessButton"] isHidden] && source.pending.count == fetches,
               @"Permission-free state offers connection without reading reminders");
        NSDate *early = [NSDate dateWithTimeIntervalSince1970:10], *late = [NSDate dateWithTimeIntervalSince1970:20];
        Expect(BarCalCompareTodos(early, 0, @"Z", late, 1, @"A") == NSOrderedAscending, @"Due dates sort before priority");
        Expect(BarCalCompareTodos(early, 0, @"Z", nil, 1, @"A") == NSOrderedAscending, @"Undated tasks sort after dated tasks");
        Expect(BarCalCompareTodos(nil, 1, @"Z", nil, 0, @"A") == NSOrderedAscending, @"No priority sorts after explicit priority");
        Expect(BarCalCompareTodos(nil, 0, @"alpha", nil, 0, @"Beta") == NSOrderedAscending, @"Ties have a stable title order");
        if (previous) [defaults setObject:previous forKey:kTodoListIdentifier];
        else [defaults removeObjectForKey:kTodoListIdentifier];
        Expect(NSApp.windows.count == 0, @"Panel tests never present a window");
        NSLog(@"PASS: list isolation, stale results, undated rows, completion routing, read-only access, empty/denied states, and ordering");
    }
    return 0;
}
