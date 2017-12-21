//
//  MKWeakTimerTarget.h
//  MapkinClient
//
//  Created by Vijay Sridhar on 11/11/15.
//  Copyright © 2015 Eightyone Labs, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MKWeakTimerTarget : NSObject

- (instancetype)initWithTarget:(id)target selector:(SEL)selector;
- (void)timerDidFire:(NSTimer *)timer;

@end

