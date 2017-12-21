//
//  NSObject+DelayedBlock.m
//

#import "NSObject+DelayedBlock.h"


@interface NSObject (PrivateDelayedBlock)

- (void)_executeDelayedBlock:(void (^)(void))block;

@end


@implementation NSObject (DelayedBlock)


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
- (void)performBlock:(void (^)(void))block afterDelay:(NSTimeInterval)delay
{
    [self performSelector:@selector(_executeDelayedBlock:)
               withObject:[block copy]
               afterDelay:delay];
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
- (void)performBlockOnMainThread:(void (^)(void))block
{
    [self performSelectorOnMainThread:@selector(_executeDelayedBlock:)
                           withObject:[block copy]
                        waitUntilDone:NO];
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
- (void)performBlockNowOnMainThread:(void (^)(void))block
{
    if ([NSThread isMainThread]) {
        block();
        return;
    }
    [self performSelectorOnMainThread:@selector(_executeDelayedBlock:)
                           withObject:[block copy]
                        waitUntilDone:NO];
}


#pragma mark - Private
// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
- (void)_executeDelayedBlock:(void (^)(void))block
{
    block();
}

@end
