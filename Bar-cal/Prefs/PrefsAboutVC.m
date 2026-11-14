//
//  Created by Sanjay Madan on 1/11/17.
//  Copyright © 2017 mowglii.com. All rights reserved.
//

#import "PrefsAboutVC.h"
#import "Itsycal.h"
#import "MoTextField.h"
#import "MoVFLHelper.h"

@implementation PrefsAboutVC

#pragma mark -
#pragma mark View lifecycle

- (void)loadView
{
    NSView *v = [NSView new];

    // The content goes in a box that hugs it. The box is centered
    // so the content stays centered when the Settings window is
    // wider than the content (see PrefsVC).
    NSView *box = [NSView new];
    [v addSubview:box];

    NSImageView *icon = [NSImageView imageViewWithImage:NSApp.applicationIconImage];
    icon.imageScaling = NSImageScaleProportionallyUpOrDown;
    [box addSubview:icon];

    // Convenience function for making labels.
    MoTextField* (^label)(NSString*, BOOL) = ^MoTextField* (NSString *stringValue, BOOL isLink) {
        MoTextField *txt = [MoTextField labelWithString:stringValue];
        if (isLink) {
            txt.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
            txt.linkEnabled = YES;
        }
        [box addSubview:txt];
        return txt;
    };

    NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
    NSTextField *appName = label(@"Bar-cal", NO);
    appName.font = [NSFont systemFontOfSize:16 weight:NSFontWeightBold];

    NSTextField *version = label([NSString stringWithFormat:@"%@ (%@)", infoDict[@"CFBundleShortVersionString"], infoDict[@"CFBundleVersion"]], NO);
    version.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
    version.textColor = [NSColor secondaryLabelColor];

    NSTextField *tagline = label(NSLocalizedString(@"A quiet calendar for your menu bar.", @""), NO);
    tagline.font = [NSFont systemFontOfSize:12];
    tagline.textColor = NSColor.secondaryLabelColor;

    MoTextField *source = label(NSLocalizedString(@"Source on GitHub", @""), YES);
    source.urlString = @"https://github.com/Kars3n/Bar-cal";

    MoTextField *licenses = label(NSLocalizedString(@"Open Source Licenses", @""), YES);
    licenses.urlString = [NSBundle.mainBundle URLForResource:@"Acknowledgments" withExtension:@"txt"].absoluteString;

    MoTextField *credit = label(@"Based on Itsycal by Sanjay Madan", YES);
    credit.urlString = @"https://github.com/sfsam/Itsycal";
    credit.font = [NSFont systemFontOfSize:11];
    NSTextField *copyright = label(@"Itsycal © 2012–2026 mowglii.com", NO);
    copyright.font = [NSFont systemFontOfSize:11];
    copyright.textColor = NSColor.secondaryLabelColor;

    MoVFLHelper *vfl = [[MoVFLHelper alloc] initWithSuperview:box metrics:@{@"m": @20} views:NSDictionaryOfVariableBindings(icon, appName, version, tagline, source, licenses, credit, copyright)];
    [vfl :@"V:|[icon(64)]-12-[appName]-6-[tagline]-m-[source]-10-[licenses]-m-[credit]-4-[copyright]|"];
    [vfl :@"H:|[icon(64)]-(>=0)-|"];
    [vfl :@"H:|[appName]-4-[version]-(>=0)-|" :NSLayoutFormatAlignAllBaseline];
    for (NSView *item in @[tagline, source, licenses, credit, copyright]) {
        [item.leadingAnchor constraintEqualToAnchor:box.leadingAnchor].active = YES;
        [item.trailingAnchor constraintLessThanOrEqualToAnchor:box.trailingAnchor].active = YES;
    }

    MoVFLHelper *outer = [[MoVFLHelper alloc] initWithSuperview:v metrics:@{@"m": @25} views:NSDictionaryOfVariableBindings(box)];
    [outer :@"V:|-m-[box]-m-|"];
    [outer :@"H:|-(>=m)-[box]-(>=m)-|"];
    [box.centerXAnchor constraintEqualToAnchor:v.centerXAnchor].active = YES;

    // Make the box as narrow as its content allows.
    NSLayoutConstraint *hug = [box.widthAnchor constraintEqualToConstant:0];
    hug.priority = 1;
    hug.active = YES;

    self.view = v;
}

@end
