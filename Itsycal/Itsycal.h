//
//  Itsycal.h
//  Itsycal
//
//  Created by Sanjay Madan on 2/3/15.
//  Copyright (c) 2015 mowglii.com. All rights reserved.
//

#import <objc/runtime.h>
#import <Cocoa/Cocoa.h>
#import "MoDate.h"

// NSUserDefaults keys
extern NSString * const kPinItsycal;
extern NSString * const kShowEventDays;
extern NSString * const kShowWeeks;
extern NSString * const kWeekStartDOW;
extern NSString * const kHighlightedDOWs;
extern NSString * const kKeyboardShortcut;
extern NSString * const kMenuBarIconType; // 0 = solid round rect (default), 1 = outlined round rect,
                                          // 2 = generic calendar icon, 3 = Itsycal icon
extern NSString * const kShowMonthInIcon;
extern NSString * const kShowDayOfWeekInIcon;
extern NSString * const kShowMeetingIndicator;
extern NSString * const kAllowOutsideApplicationsFolder;
extern NSString * const kClockFormat;
extern NSString * const kHideIcon;
extern NSString * const kShowLocation;
extern NSString * const kShowEventDots;
extern NSString * const kUseColoredDots;
extern NSString * const kBeepBeepOnTheHour;
extern NSString * const kBaselineOffset;
extern NSString * const kEnableMeetingButtonIndefinitely;
extern NSString * const kDoNotDrawOutlineAroundCurrentMonth;
extern NSString * const kShowDaysWithNoEventsInAgenda;
extern NSString * const kShowCompletedReminders;
extern NSString * const kShowOverdueReminders;
extern NSString * const kOverdueSectionExpanded;
extern NSString * const kShowEventPopoverOnHover;
extern NSString * const kDoNotCheckLoginItemStatus;
extern NSString * const kWindowPosition;
extern NSString * const kTimerEndDate;
extern NSString * const kTimerRecentMinutes;
extern NSString * const kPresentationMode;
extern NSString * const kScreenEdge;
extern NSString * const kEdgeTabPosition;
extern NSString * const kEdgeTabDisplay;
extern NSString * const kEdgeTabAnchor;
extern NSString * const kDrawerTabsEnabled;
extern NSString * const kSelectedDrawerTab;
extern NSString * const kTodoListIdentifier;

typedef NS_ENUM(NSInteger, BarCalDrawerTab) {
    BarCalDrawerTabCalendar = 0,
    BarCalDrawerTabTodo = 1
};

typedef NS_ENUM(NSInteger, BarCalPresentationMode) {
    BarCalPresentationMenuBar = 0,
    BarCalPresentationScreenEdge = 1
};

typedef NS_ENUM(NSInteger, BarCalScreenEdge) {
    BarCalScreenEdgeRight = 0,
    BarCalScreenEdgeLeft = 1
};

typedef NS_ENUM(NSInteger, WindowPosition) {
    WindowPositionBelowMenuBarIcon = 0,
    WindowPositionTopRightOfScreen = 1
};

// Set an associated object on NSDate to indicate
// whether of not this date has events.
// https://stackoverflow.com/a/16708352
@interface NSDate (HasNoEvents)
@property (nonatomic) BOOL hasNoEvents;
@end
