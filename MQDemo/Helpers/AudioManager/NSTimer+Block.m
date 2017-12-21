//
//  NSTimer+Block.m
//  MapkinClient
//
//  Created by Alex on 5/29/14.
//  Copyright (c) 2014 Eightyone Labs, Inc. All rights reserved.
//

#import "NSTimer+Block.h"
#import "MKWeakTimerTarget.h"


typedef void(^Completion)(void);


@implementation NSTimer (Block)

// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
+ (NSTimer *)scheduledTimerWithTimeInterval:(NSTimeInterval)ti block:(Completion)completion
{
    return [NSTimer scheduledTimerWithTimeInterval:ti
                                            target:[NSTimer class]
                                          selector:@selector(_handler:)
                                          userInfo:completion
                                           repeats:NO];
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
+ (NSTimer *)scheduledTimerWithTimeInterval:(NSTimeInterval)timeInterval
                                 weakTarget:(id)target
                                   selector:(SEL)selector
                                   userInfo:(id)userInfo
                                    repeats:(BOOL)yesOrNo
{
    return [self scheduledTimerWithTimeInterval:timeInterval
                                         target:[[MKWeakTimerTarget alloc] initWithTarget:target selector:selector]
                                       selector:@selector(timerDidFire:)
                                       userInfo:userInfo
                                        repeats:yesOrNo];
}

// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
+ (void)_handler:(NSTimer*)timer
{
    Completion comp = timer.userInfo;
    if (comp) {
        comp();
    }
}


@end
