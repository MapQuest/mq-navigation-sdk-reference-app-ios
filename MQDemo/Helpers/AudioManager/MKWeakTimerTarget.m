//
//  MKWeakTimerTarget.m
//  MapkinClient
//
//  Created by Vijay Sridhar on 11/11/15.
//  Copyright © 2015 Eightyone Labs, Inc. All rights reserved.
//

#import "MKWeakTimerTarget.h"

@interface MKWeakTimerTarget()

@property (nonatomic, weak) id target;
@property (nonatomic) SEL selector;

@end

@implementation MKWeakTimerTarget

#pragma mark - Initialization
// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
- (instancetype)initWithTarget:(id)target selector:(SEL)selector
{
    if (self = [super init]) {
        _target = target;
        _selector = selector;
    }
    
    return self;
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
- (id)init
{
    return [self initWithTarget:nil selector:nil];
}

#pragma mark - TMWeakTimerTarget
// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
- (void)timerDidFire:(NSTimer *)timer
{
    if (self.target) {
        if (!self.target) { return; }
        IMP imp = [self.target methodForSelector:self.selector];
        void (*func)(id, SEL) = (void *)imp;
        func(self.target, self.selector);
    } else {
        [timer invalidate];
    }
}

@end