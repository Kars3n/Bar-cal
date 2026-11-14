#import "TodoViewController.h"
#import "EventCenter.h"
#import "Itsycal.h"
#import "Themer.h"
#import "Sizer.h"

@interface TodoRow : NSTableCellView
@property (nonatomic) NSButton *complete;
@property (nonatomic) NSTextField *titleLabel;
@property (nonatomic) NSTextField *dueLabel;
@property (nonatomic, copy) NSString *reminderIdentifier;
@end

@implementation TodoRow
- (instancetype)init
{
    if ((self = [super init])) {
        _complete = [NSButton checkboxWithTitle:@"" target:nil action:nil];
        _complete.translatesAutoresizingMaskIntoConstraints = NO;
        _titleLabel = [NSTextField wrappingLabelWithString:@""];
        _titleLabel.maximumNumberOfLines = 2;
        _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        _dueLabel = [NSTextField labelWithString:@""];
        _dueLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        for (NSView *view in @[_complete, _titleLabel, _dueLabel]) {
            view.translatesAutoresizingMaskIntoConstraints = NO;
            [self addSubview:view];
        }
        [NSLayoutConstraint activateConstraints:@[
            [_complete.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:9],
            [_complete.topAnchor constraintEqualToAnchor:self.topAnchor constant:6],
            [_complete.widthAnchor constraintEqualToConstant:18],
            [_titleLabel.leadingAnchor constraintEqualToAnchor:_complete.trailingAnchor constant:5],
            [_titleLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-9],
            [_titleLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:5],
            [_dueLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
            [_dueLabel.trailingAnchor constraintEqualToAnchor:_titleLabel.trailingAnchor],
            [_dueLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:3],
            [_dueLabel.bottomAnchor constraintLessThanOrEqualToAnchor:self.bottomAnchor constant:-6],
        ]];
    }
    return self;
}
- (void)drawRect:(NSRect)dirtyRect
{
    [Theme.agendaDividerColor setFill];
    NSRectFill(NSMakeRect(9, 0, MAX(0, NSWidth(self.bounds) - 18), 0.5));
}
@end

@implementation TodoViewController
{
    NSTextField *_heading, *_count, *_message;
    NSPopUpButton *_listsPopup;
    NSButton *_accessButton;
    NSTableView *_table;
    NSScrollView *_scroll;
    NSArray<EventInfo *> *_items;
    NSArray<CalendarInfo *> *_lists;
    NSUInteger _fetchGeneration;
    id _activeObserver;
}

- (void)loadView
{
    NSView *view = [NSView new];
    view.translatesAutoresizingMaskIntoConstraints = NO;
    _heading = [NSTextField labelWithString:NSLocalizedString(@"To-do", @"")];
    _count = [NSTextField labelWithString:@""];
    _count.font = [NSFont monospacedDigitSystemFontOfSize:11 weight:NSFontWeightRegular];
    _count.textColor = Theme.agendaEventDateTextColor;
    _count.toolTip = NSLocalizedString(@"Incomplete reminders, sorted by due date and priority", @"");
    _listsPopup = [NSPopUpButton new];
    _listsPopup.controlSize = NSControlSizeSmall;
    _listsPopup.font = [NSFont systemFontOfSize:11];
    _listsPopup.target = self;
    _listsPopup.action = @selector(listChanged:);
    _listsPopup.accessibilityLabel = NSLocalizedString(@"Reminder list", @"");

    _table = [NSTableView new];
    _table.headerView = nil;
    _table.backgroundColor = NSColor.clearColor;
    _table.intercellSpacing = NSMakeSize(0, 0);
    _table.selectionHighlightStyle = NSTableViewSelectionHighlightStyleNone;
    _table.dataSource = self;
    _table.delegate = self;
    _table.style = NSTableViewStylePlain;
    [_table addTableColumn:[[NSTableColumn alloc] initWithIdentifier:@"Todo"]];
    _scroll = [NSScrollView new];
    _scroll.drawsBackground = NO;
    _scroll.borderType = NSNoBorder;
    _scroll.hasVerticalScroller = YES;
    _scroll.autohidesScrollers = YES;
    _scroll.documentView = _table;
    _table.autoresizingMask = NSViewWidthSizable;

    _message = [NSTextField wrappingLabelWithString:@""];
    _message.font = [NSFont systemFontOfSize:11];
    _message.textColor = Theme.agendaEventDateTextColor;
    _message.alignment = NSTextAlignmentCenter;
    _accessButton = [NSButton buttonWithTitle:NSLocalizedString(@"Connect Reminders", @"") target:self action:@selector(connectReminders:)];
    _accessButton.controlSize = NSControlSizeSmall;
    _accessButton.bezelStyle = NSBezelStyleRounded;

    NSButton *open = [NSButton buttonWithTitle:NSLocalizedString(@"Reminders", @"") target:self action:@selector(openReminders:)];
    open.bordered = NO;
    open.font = [NSFont systemFontOfSize:11];
    open.contentTintColor = Theme.buttonTintColor;
    open.toolTip = NSLocalizedString(@"Open Apple Reminders", @"");
    NSButton *settings = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"gearshape" accessibilityDescription:NSLocalizedString(@"Settings", @"")] target:self action:@selector(settings:)];
    settings.bordered = NO;
    settings.contentTintColor = Theme.buttonTintColor;
    NSButton *pin = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"pin" accessibilityDescription:NSLocalizedString(@"Pin Bar-cal", @"")] target:nil action:nil];
    pin.alternateImage = [NSImage imageWithSystemSymbolName:@"pin.fill" accessibilityDescription:nil];
    [pin setButtonType:NSButtonTypeToggle];
    pin.bordered = NO;
    pin.contentTintColor = Theme.buttonTintColor;
    pin.accessibilityLabel = NSLocalizedString(@"Pin Bar-cal", @"");
    [pin bind:@"value" toObject:NSUserDefaultsController.sharedUserDefaultsController withKeyPath:[@"values." stringByAppendingString:kPinItsycal] options:@{NSContinuouslyUpdatesValueBindingOption: @YES}];
    for (NSView *child in @[_heading, _count, _listsPopup, _scroll, _message, _accessButton, open, pin, settings]) {
        child.translatesAutoresizingMaskIntoConstraints = NO;
        [view addSubview:child];
    }
    [NSLayoutConstraint activateConstraints:@[
        [_heading.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:10],
        [_heading.topAnchor constraintEqualToAnchor:view.topAnchor constant:1],
        [_count.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-11],
        [_count.firstBaselineAnchor constraintEqualToAnchor:_heading.firstBaselineAnchor],
        [_heading.trailingAnchor constraintLessThanOrEqualToAnchor:_count.leadingAnchor constant:-6],
        [_listsPopup.topAnchor constraintEqualToAnchor:_heading.bottomAnchor constant:8],
        [_listsPopup.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:8],
        [_listsPopup.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-8],
        [_scroll.topAnchor constraintEqualToAnchor:_listsPopup.bottomAnchor constant:8],
        [_scroll.leadingAnchor constraintEqualToAnchor:view.leadingAnchor],
        [_scroll.trailingAnchor constraintEqualToAnchor:view.trailingAnchor],
        [_scroll.bottomAnchor constraintEqualToAnchor:open.topAnchor constant:-6],
        [open.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:10],
        [open.bottomAnchor constraintEqualToAnchor:view.bottomAnchor constant:-1],
        [settings.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-9],
        [settings.centerYAnchor constraintEqualToAnchor:open.centerYAnchor],
        [settings.widthAnchor constraintEqualToConstant:22],
        [settings.heightAnchor constraintEqualToConstant:22],
        [pin.trailingAnchor constraintEqualToAnchor:settings.leadingAnchor constant:-7],
        [pin.centerYAnchor constraintEqualToAnchor:settings.centerYAnchor],
        [pin.widthAnchor constraintEqualToConstant:22],
        [pin.heightAnchor constraintEqualToConstant:22],
        [_message.centerXAnchor constraintEqualToAnchor:_scroll.centerXAnchor],
        [_message.centerYAnchor constraintEqualToAnchor:_scroll.centerYAnchor constant:-14],
        [_message.widthAnchor constraintEqualToAnchor:view.widthAnchor constant:-24],
        [_accessButton.topAnchor constraintEqualToAnchor:_message.bottomAnchor constant:9],
        [_accessButton.centerXAnchor constraintEqualToAnchor:view.centerXAnchor],
    ]];
    self.view = view;
    _items = @[];
    REGISTER_FOR_SIZE_CHANGE;
    [self sizeChanged:nil];
    __weak typeof(self) weakSelf = self;
    _activeObserver = [NSNotificationCenter.defaultCenter addObserverForName:NSApplicationDidBecomeActiveNotification object:NSApp queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
        if (weakSelf.active) [weakSelf reload];
    }];
}

- (void)dealloc
{
    [NSNotificationCenter.defaultCenter removeObserver:self];
    if (_activeObserver) [NSNotificationCenter.defaultCenter removeObserver:_activeObserver];
}

- (void)sizeChanged:(id)sender
{
    _heading.font = [NSFont systemFontOfSize:SizePref.calendarTitleFontSize weight:NSFontWeightSemibold];
    _heading.textColor = Theme.monthTextColor;
    _table.rowHeight = ceil(SizePref.fontSize * 3.4 + 18);
    [_table reloadData];
}

- (void)setActive:(BOOL)active
{
    if (_active == active) return;
    _active = active;
    if (active) [self reload];
    else ++_fetchGeneration;
}

- (void)showMessage:(NSString *)message action:(BOOL)action
{
    _message.stringValue = message ?: @"";
    _message.hidden = message.length == 0;
    _accessButton.hidden = !action;
}

- (void)reload
{
    if (!self.isViewLoaded || !self.eventCenter) return;
    NSUInteger generation = ++_fetchGeneration;
    [_listsPopup removeAllItems];
    [_listsPopup addItemWithTitle:NSLocalizedString(@"Choose a list…", @"")];
    NSMutableArray *lists = [NSMutableArray new];
    NSString *identifier = [NSUserDefaults.standardUserDefaults stringForKey:kTodoListIdentifier];
    for (id object in self.eventCenter.sourcesAndCalendars) {
        if (![object isKindOfClass:CalendarInfo.class]) continue;
        CalendarInfo *info = object;
        if (!(info.calendar.allowedEntityTypes & EKEntityMaskReminder)) continue;
        [lists addObject:info];
        NSString *title = [NSString stringWithFormat:@"%@ — %@", info.calendar.title, info.calendar.source.title ?: @""];
        [_listsPopup addItemWithTitle:title];
        _listsPopup.lastItem.representedObject = info.calendar.calendarIdentifier;
        if ([identifier isEqualToString:info.calendar.calendarIdentifier]) [_listsPopup selectItem:_listsPopup.lastItem];
    }
    _lists = lists.copy;
    BOOL access = self.eventCenter.remindersAuthorizationStatus == EKAuthorizationStatusFullAccess;
    _listsPopup.enabled = access && _lists.count > 0;
    _items = @[];
    [_table reloadData];
    _count.stringValue = @"";
    if (!access) {
        BOOL denied = self.eventCenter.remindersAuthorizationStatus != EKAuthorizationStatusNotDetermined;
        _accessButton.title = denied ? NSLocalizedString(@"Open Settings", @"") : NSLocalizedString(@"Connect Reminders", @"");
        [self showMessage:denied ? NSLocalizedString(@"Allow Bar-cal in Privacy & Security › Reminders.", @"")
                                : NSLocalizedString(@"Mirror one of your Apple Reminders lists here.", @"") action:YES];
        return;
    }
    if (_listsPopup.indexOfSelectedItem == 0) {
        [self showMessage:_lists.count == 0 ? NSLocalizedString(@"No reminder lists are available.", @"")
            : identifier.length ? NSLocalizedString(@"List unavailable. Choose another list above.", @"")
                                : NSLocalizedString(@"Choose a reminder list above to see your to-dos.", @"") action:NO];
        return;
    }
    if (!self.active) return;
    [self showMessage:NSLocalizedString(@"Updating…", @"") action:NO];
    __weak typeof(self) weakSelf = self;
    [self.eventCenter fetchTodoList:identifier completion:^(NSArray<EventInfo *> *items, NSError *error) {
        typeof(self) strongSelf = weakSelf;
        if (!strongSelf || generation != strongSelf->_fetchGeneration || !strongSelf.active) return;
        strongSelf->_items = items;
        strongSelf->_count.stringValue = [NSNumberFormatter localizedStringFromNumber:@(items.count) numberStyle:NSNumberFormatterDecimalStyle];
        [strongSelf->_table reloadData];
        [strongSelf showMessage:error ? error.localizedDescription : items.count ? @"" : NSLocalizedString(@"All caught up", @"") action:NO];
    }];
}

- (void)listChanged:(id)sender
{
    NSString *identifier = _listsPopup.selectedItem.representedObject ?: @"";
    [NSUserDefaults.standardUserDefaults setObject:identifier forKey:kTodoListIdentifier];
    [self reload];
}

- (void)connectReminders:(id)sender
{
    if (self.eventCenter.remindersAuthorizationStatus == EKAuthorizationStatusNotDetermined) {
        [self.eventCenter requestRemindersAccessWithCompletion:^{ [self reload]; }];
    } else {
        [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders"]];
    }
}
- (void)openReminders:(id)sender { [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:@"x-apple-reminderkit://"]]; }
- (void)settings:(id)sender { if (self.showSettings) self.showSettings(); }

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView { return _items.count; }
- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row { return NO; }

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)column row:(NSInteger)row
{
    EventInfo *info = _items[row];
    TodoRow *cell = (TodoRow *)[tableView makeViewWithIdentifier:@"TodoRow" owner:self];
    if (!cell) { cell = [TodoRow new]; cell.identifier = @"TodoRow"; }
    cell.reminderIdentifier = info.reminder.calendarItemIdentifier;
    cell.titleLabel.stringValue = info.reminder.title ?: @"";
    cell.titleLabel.font = [NSFont systemFontOfSize:SizePref.fontSize];
    cell.titleLabel.textColor = Theme.agendaEventTextColor;
    cell.titleLabel.toolTip = info.reminder.title;
    cell.complete.target = self;
    cell.complete.action = @selector(complete:);
    cell.complete.state = info.reminder.isCompleted ? NSControlStateValueOn : NSControlStateValueOff;
    cell.complete.enabled = info.reminder.calendar.allowsContentModifications;
    cell.complete.accessibilityLabel = [NSString stringWithFormat:NSLocalizedString(@"Complete %@", @""), info.reminder.title ?: @""];
    cell.dueLabel.font = [NSFont systemFontOfSize:MAX(10, SizePref.fontSize - 1)];
    cell.dueLabel.textColor = Theme.agendaEventDateTextColor;
    if (info.dueDate) {
        NSDateFormatter *format = [NSDateFormatter new];
        format.doesRelativeDateFormatting = YES;
        format.dateStyle = NSDateFormatterShortStyle;
        format.timeStyle = info.isAllDay ? NSDateFormatterNoStyle : NSDateFormatterShortStyle;
        cell.dueLabel.stringValue = [format stringFromDate:info.dueDate];
        NSDate *deadline = info.isAllDay ? [NSCalendar.currentCalendar startOfDayForDate:NSDate.date] : NSDate.date;
        if ([info.dueDate compare:deadline] == NSOrderedAscending) cell.dueLabel.textColor = Theme.agendaOverdueTextColor;
    } else cell.dueLabel.stringValue = NSLocalizedString(@"No due date", @"");
    return cell;
}

- (void)complete:(NSButton *)sender
{
    TodoRow *cell = (TodoRow *)sender.superview;
    EventInfo *info = [_items filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(EventInfo *item, NSDictionary *bindings) {
        return [item.reminder.calendarItemIdentifier isEqualToString:cell.reminderIdentifier];
    }]].firstObject;
    if (!info) { [self reload]; return; }
    NSError *error = nil;
    if (![self.eventCenter setReminder:info.reminder completed:YES undoManager:self.view.window.undoManager error:&error]) {
        sender.state = NSControlStateValueOff;
        NSAlert *alert = [NSAlert new];
        alert.messageText = NSLocalizedString(@"Couldn’t complete this reminder", @"");
        alert.informativeText = error.localizedDescription ?: NSLocalizedString(@"Try again after Reminders finishes syncing.", @"");
        [alert runModal];
    }
    [self reload];
}
@end
