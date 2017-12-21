//
//  NSObject+DelayedBlock.h
//

#import <Foundation/Foundation.h>


@interface NSObject (DelayedBlock)


- (void)performBlock:(void (^)(void))block afterDelay:(NSTimeInterval)delay;
- (void)performBlockOnMainThread:(void (^)(void))block;
- (void)performBlockNowOnMainThread:(void (^)(void))block;

@end
