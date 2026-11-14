//
//  Created by Sanjay Madan on 1/11/17.
//  Copyright © 2017 mowglii.com. All rights reserved.
//

#import "PrefsGeneralVC.h"
#import "Itsycal.h"
#import "MoLoginItem.h"
#import "MoVFLHelper.h"
#import "MASShortcut/Shortcut.h"

@implementation PrefsGeneralVC
{
    NSButton *_login;
    NSPopUpButton *_positionPopup;
    NSPopUpButton *_edgePopup;
    NSButton *_drawerTabs;
}

#pragma mark -
#pragma mark View lifecycle

- (void)loadView
{
    // View controller content view
    NSView *v = [NSView new];

    // Convenience function for making labels.
    NSTextField* (^label)(NSString*) = ^NSTextField* (NSString *stringValue) {
        NSTextField *txt = [NSTextField labelWithString:stringValue];
        [v addSubview:txt];
        return txt;
    };

    // Convenience function for making checkboxes.
    NSButton* (^chkbx)(NSString *) = ^NSButton* (NSString *title) {
        NSButton *chkbx = [NSButton checkboxWithTitle:title target:self action:nil];
        [v addSubview:chkbx];
        return chkbx;
    };

    // Checkboxes
    _login = chkbx(NSLocalizedString(@"Launch at login", @""));
    _login.action = @selector(launchAtLogin:);
    NSButton *beepBeep = chkbx(NSLocalizedString(@"Beep beep on the hour", @""));

    // Shortcut label
    NSTextField *shortcutLabel = label(NSLocalizedString(@"Keyboard shortcut", @""));

    // Shortcut view
    MASShortcutView *shortcutView = [MASShortcutView new];
    [shortcutView setAssociatedUserDefaultsKey:kKeyboardShortcut withTransformerName:MASDictionaryTransformerName];
    [v addSubview:shortcutView];

    // Window position label
    NSTextField *positionLabel = label(NSLocalizedString(@"Menu bar popup:", @""));

    // Window position popup
    NSPopUpButton *positionPopup = [NSPopUpButton new];
    _positionPopup = positionPopup;
    [positionPopup addItemsWithTitles:@[NSLocalizedString(@"Below menu bar icon", @""),
                                        NSLocalizedString(@"Top right of screen", @"")]];
    // The tags will be used to bind the selected window
    // position preference to NSUserDefaults.
    [positionPopup itemAtIndex:0].tag = WindowPositionBelowMenuBarIcon;
    [positionPopup itemAtIndex:1].tag = WindowPositionTopRightOfScreen;
    [positionPopup.cell setAccessibilityTitleUIElement:positionLabel.cell];
    [v addSubview:positionPopup];

    NSTextField *presentationLabel = label(NSLocalizedString(@"Show calendar as:", @""));
    NSPopUpButton *presentationPopup = [NSPopUpButton new];
    [presentationPopup addItemsWithTitles:@[NSLocalizedString(@"Menu bar item", @""), NSLocalizedString(@"Screen-edge tab", @"")]];
    [presentationPopup itemAtIndex:0].tag = BarCalPresentationMenuBar;
    [presentationPopup itemAtIndex:1].tag = BarCalPresentationScreenEdge;
    presentationPopup.target = self;
    presentationPopup.action = @selector(presentationChanged:);
    [presentationPopup.cell setAccessibilityTitleUIElement:presentationLabel.cell];
    [v addSubview:presentationPopup];

    NSTextField *edgeLabel = label(NSLocalizedString(@"Screen edge:", @""));
    NSPopUpButton *edgePopup = [NSPopUpButton new];
    _edgePopup = edgePopup;
    [edgePopup addItemsWithTitles:@[NSLocalizedString(@"Right", @""), NSLocalizedString(@"Left", @"")]];
    [edgePopup itemAtIndex:0].tag = BarCalScreenEdgeRight;
    [edgePopup itemAtIndex:1].tag = BarCalScreenEdgeLeft;
    [edgePopup.cell setAccessibilityTitleUIElement:edgeLabel.cell];
    [v addSubview:edgePopup];

    NSTextField *edgeHint = label(NSLocalizedString(@"Click the edge tab to open or close. Drag it to reposition.", @""));
    edgeHint.font = [NSFont systemFontOfSize:11];
    edgeHint.textColor = NSColor.secondaryLabelColor;
    _drawerTabs = chkbx(NSLocalizedString(@"Show Calendar & To-do tabs", @""));
    _drawerTabs.toolTip = NSLocalizedString(@"Use two adjacent tabs in one screen-edge drawer. Choose a reminder list inside To-do.", @"");

    MoVFLHelper *vfl = [[MoVFLHelper alloc] initWithSuperview:v metrics:@{@"m": @20} views:NSDictionaryOfVariableBindings(_login, beepBeep, shortcutLabel, shortcutView, presentationLabel, presentationPopup, edgeLabel, edgePopup, edgeHint, _drawerTabs, positionLabel, positionPopup)];
    [vfl :@"V:|-m-[_login]-[beepBeep]-m-[shortcutLabel]-3-[shortcutView(25)]-m-[presentationPopup]-10-[edgePopup]-8-[edgeHint]-12-[_drawerTabs]-m-[positionPopup]-m-|"];
    [vfl :@"H:|-m-[_login]-(>=m)-|"];
    [vfl :@"H:|-m-[beepBeep]-(>=m)-|"];
    [vfl :@"H:|-(>=m)-[shortcutLabel]-(>=m)-|"];
    [vfl :@"H:|-m-[shortcutView(>=220)]-m-|"];
    [vfl :@"H:|-m-[positionLabel]-[positionPopup]-(>=m)-|" :NSLayoutFormatAlignAllFirstBaseline];
    [vfl :@"H:|-m-[presentationLabel]-[presentationPopup]-(>=m)-|" :NSLayoutFormatAlignAllFirstBaseline];
    [vfl :@"H:|-m-[edgeLabel]-[edgePopup]-(>=m)-|" :NSLayoutFormatAlignAllFirstBaseline];
    [vfl :@"H:|-m-[edgeHint]-(>=m)-|"];
    [vfl :@"H:|-m-[_drawerTabs]-(>=m)-|"];

    // Center shortcutLabel
    [v addConstraint:[NSLayoutConstraint constraintWithItem:shortcutLabel attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:v attribute:NSLayoutAttributeCenterX multiplier:1 constant:0]];

    // Binding for hourly beep
    [beepBeep bind:@"value" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kBeepBeepOnTheHour] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];

    // Bindings for window position
    [positionPopup bind:@"selectedTag" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kWindowPosition] options:@{NSContinuouslyUpdatesValueBindingOption: @(YES)}];
    [presentationPopup bind:@"selectedTag" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kPresentationMode] options:@{NSContinuouslyUpdatesValueBindingOption: @YES}];
    [edgePopup bind:@"selectedTag" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:kScreenEdge] options:@{NSContinuouslyUpdatesValueBindingOption: @YES}];
    [_drawerTabs bind:@"value" toObject:NSUserDefaultsController.sharedUserDefaultsController withKeyPath:[@"values." stringByAppendingString:kDrawerTabsEnabled] options:@{NSContinuouslyUpdatesValueBindingOption: @YES}];


    self.view = v;
}

- (void)viewWillAppear
{
    [super viewWillAppear];
    [self updatePresentationControls:[NSUserDefaults.standardUserDefaults integerForKey:kPresentationMode]];

    // The API used to check the login item's state (LSSharedFileList) causes
    // errors for users who have network drives but are not connected to their
    // network (github.com/sfsam/Itsycal/issues/15). Give them an option to
    // disable this check.
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kDoNotCheckLoginItemStatus] == NO) {
        _login.hidden = NO;
        _login.state = MOIsLoginItemEnabled() ? NSControlStateValueOn : NSControlStateValueOff;
    }
    else {
        _login.hidden = YES;
    }
}

#pragma mark -
#pragma mark Presentation

- (void)presentationChanged:(NSPopUpButton *)popup
{
    [self updatePresentationControls:popup.selectedTag];
}

- (void)updatePresentationControls:(NSInteger)mode
{
    BOOL screenEdge = mode == BarCalPresentationScreenEdge;
    _edgePopup.enabled = screenEdge;
    _positionPopup.enabled = !screenEdge;
    _drawerTabs.enabled = screenEdge;
}

#pragma mark -
#pragma mark Login item

- (void)launchAtLogin:(NSButton *)login
{
    MOEnableLoginItem(login.state == NSControlStateValueOn);
}

@end
