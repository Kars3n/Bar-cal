#import <Foundation/Foundation.h>

// Due reminders first, then priority and title. EventKit does not expose the
// Reminders app's manual row order. A priority of zero means no priority.
static inline NSComparisonResult BarCalCompareTodos(NSDate *dueA, NSInteger priorityA, NSString *titleA,
                                                   NSDate *dueB, NSInteger priorityB, NSString *titleB)
{
    if (dueA && !dueB) return NSOrderedAscending;
    if (!dueA && dueB) return NSOrderedDescending;
    if (dueA && dueB) {
        NSComparisonResult dates = [dueA compare:dueB];
        if (dates != NSOrderedSame) return dates;
    }
    NSInteger a = priorityA == 0 ? 10 : priorityA;
    NSInteger b = priorityB == 0 ? 10 : priorityB;
    if (a != b) return a < b ? NSOrderedAscending : NSOrderedDescending;
    return [(titleA ?: @"") localizedCaseInsensitiveCompare:(titleB ?: @"")];
}
