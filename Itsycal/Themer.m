//
//  Created by Sanjay Madan on 6/12/17.
//  Copyright © 2017 mowglii.com. All rights reserved.
//

#import "Themer.h"
#import "Itsycal.h"
#import "MoUtils.h"

// NSUserDefaults key
NSString * const kThemePreference = @"ThemePreference";

// Returns a color that resolves to light in Light Mode
// and dark in Dark Mode.
static NSColor *LightDarkColor(NSColor *light, NSColor *dark)
{
    return [NSColor colorWithName:nil dynamicProvider:^NSColor *(NSAppearance *appearance) {
        BOOL isDark = [appearance bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]] == NSAppearanceNameDarkAqua;
        return isDark ? dark : light;
    }];
}

// Semantic colors remain dynamic so changing themes updates existing views.
static NSColor *SlateColor(NSColor *fallback, NSUInteger hex)
{
    return [NSColor colorWithName:nil dynamicProvider:^NSColor *(NSAppearance *appearance) {
        if (Theme.themePreference != ThemePreferenceSlate) return fallback;
        return [NSColor colorWithSRGBRed:((hex >> 16) & 255) / 255.0
                                  green:((hex >> 8) & 255) / 255.0
                                   blue:(hex & 255) / 255.0 alpha:1];
    }];
}

static void RedrawThemeViews(NSView *view)
{
    [view setNeedsDisplay:YES];
    for (NSView *child in view.subviews) RedrawThemeViews(child);
}

@implementation Themer

Themer *Theme = nil;

+ (instancetype)shared
{
    static Themer *shared;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[Themer alloc] init];
        Theme = shared;
    });
    return shared;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _themePreference = [[NSUserDefaults standardUserDefaults] integerForKey:kThemePreference];
        [self adjustAppAppearanceForThemePreference];
    }
    return self;
}

- (void)setThemePreference:(ThemePreference)themePref {
    // Validate themePref before setting ivar.
    _themePreference = (themePref < 0 || themePref > ThemePreferenceSlate) ? ThemePreferenceSlate : themePref;
    [self adjustAppAppearanceForThemePreference];
    for (NSWindow *window in NSApp.windows) {
        RedrawThemeViews(window.contentView);
    }
}

- (void)adjustAppAppearanceForThemePreference {
    switch (_themePreference) {
        case ThemePreferenceSystem:
            NSApp.appearance = nil;
            break;
        case ThemePreferenceDark:
        case ThemePreferenceSlate:
            NSApp.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
            break;
        case ThemePreferenceLight:
        default:
            NSApp.appearance = [NSAppearance appearanceNamed:NSAppearanceNameAqua];
    }
}

- (NSColor *)agendaDayTextColor {
    return SlateColor(NSColor.secondaryLabelColor, 0xB9BAC3);
}

- (NSColor *)agendaDividerColor {
    return SlateColor(NSColor.separatorColor, 0x454752);
}

- (NSColor *)agendaDOWTextColor {
    return [self monthTextColor];
}

- (NSColor *)agendaEventDateTextColor {
    return SlateColor(NSColor.secondaryLabelColor, 0xB9BAC3);
}

- (NSColor *)agendaEventTextColor {
    return [self monthTextColor];
}

- (NSColor *)agendaHoverColor {
    return [self highlightedDOWBackgroundColor];
}

- (NSColor *)agendaOverdueTextColor {
    // Reminders shows overdue due dates in system red.
    return NSColor.systemRedColor;
}

- (NSColor *)buttonTintColor {
    return SlateColor(LightDarkColor([NSColor colorWithWhite:0.45 alpha:1], [NSColor colorWithWhite:0.55 alpha:1]), 0xC8C9D0);
}

- (NSColor *)currentMonthOutlineColor {
    return SlateColor(LightDarkColor(NSColor.labelColor, NSColor.secondaryLabelColor), 0x7877E8);
}

- (NSColor *)currentMonthTextColor {
    return SlateColor(NSColor.labelColor, 0xEEEDEB);
}

- (NSColor *)DOWTextColor {
    return SlateColor(NSColor.labelColor, 0xC9CAD1);
}

- (NSColor *)highlightedDOWBackgroundColor {
    return SlateColor(NSColor.secondarySystemFillColor, 0x353740);
}

- (NSColor *)highlightedDOWTextColor {
    return SlateColor(NSColor.secondaryLabelColor, 0xBBBCC6);
}

- (NSColor *)hoveredCellColor {
    return SlateColor(NSColor.tertiaryLabelColor, 0x8D8FA2);
}

- (NSColor *)mainBackgroundColor {
    // windowBackgroundColor is white in Light Mode. In Dark
    // Mode, use a gray halfway between windowBackgroundColor
    // (0.118) and underPageBackgroundColor (0.157).
    return SlateColor(LightDarkColor(NSColor.windowBackgroundColor, [NSColor colorWithWhite:0.137 alpha:1]), 0x24262E);
}

- (NSColor *)monthTextColor {
    return SlateColor(NSColor.labelColor, 0xEEEDEB);
}

- (NSColor *)noncurrentMonthTextColor {
    return SlateColor(NSColor.tertiaryLabelColor, 0x8E909C);
}

- (NSColor *)pendingBackgroundColor {
    return SlateColor(NSColor.secondarySystemFillColor, 0x353740);
}

- (NSColor *)resizeHandleBackgroundColor {
    return [self highlightedDOWBackgroundColor];
}

- (NSColor *)resizeHandleForegroundColor {
    return SlateColor(NSColor.secondaryLabelColor, 0x606370);
}

- (NSColor *)selectedCellColor {
    return [self currentMonthOutlineColor];
}

- (NSColor *)todayCellColor {
    // White date text has 4.65:1 contrast against this periwinkle fill.
    return SlateColor(NSColor.systemBlueColor, 0x6B68D0);
}

- (NSColor *)tooltipBackgroundColor {
    return SlateColor(LightDarkColor(NSColor.windowBackgroundColor, [NSColor colorWithWhite:0.17 alpha:1]), 0x30323D);
}

- (NSColor *)weekTextColor {
    return SlateColor(NSColor.secondaryLabelColor, 0xB9BAC3);
}

@end
