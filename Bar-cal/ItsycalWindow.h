//
//  ItsycalWindow.h
//  Itsycal
//
//  Created by Sanjay Madan on 12/14/14.
//  Copyright (c) 2014 mowglii.com. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ItsycalWindow : NSPanel

@property (nonatomic) BOOL screenEdgeMode;
@property (nonatomic) BOOL screenEdgeOnLeft;
@property (nonatomic, readonly) NSView *calendarContentView;
@property (nonatomic, readonly) CGFloat edgeRevealOffset;

- (void)setEdgeHandleView:(NSView *)view;
- (void)setEdgeHandleFrame:(NSRect)frame;
- (void)setEdgeRevealOffset:(CGFloat)offset;
- (void)animateEdgeRevealTo:(CGFloat)offset duration:(NSTimeInterval)duration completion:(void (^)(void))completion;

- (void)positionRelativeToRect:(NSRect)rect screenMaxX:(CGFloat)screenMaxX;

@end
