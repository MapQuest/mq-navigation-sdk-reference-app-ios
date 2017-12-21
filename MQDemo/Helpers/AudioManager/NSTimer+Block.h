//
//  NSTimer+Block.h
//  MapkinClient
//
//  Created by Alex on 5/29/14.
//  Copyright (c) 2014 Eightyone Labs, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSTimer (Block)
+ (NSTimer *)scheduledTimerWithTimeInterval:(NSTimeInterval)ti block:(void (^)(void))completion;

// retain cycle prevention
+ (NSTimer *)scheduledTimerWithTimeInterval:(NSTimeInterval)timeInterval
                                 weakTarget:(id)target
                                   selector:(SEL)selector
                                   userInfo:(id)userInfo
                                    repeats:(BOOL)yesOrNo;
@end
