//
//  main.m
//  iOSAnixart
//
//  Created by Toilettrauma on 16.08.2024.
//

#import <UIKit/UIKit.h>
#import "AppDelegate.h"

int main(int argc, char * argv[]) {
    NSString * appDelegateClassName;
    @autoreleasepool {
        // Setup code that might create autoreleased objects goes here.
        appDelegateClassName = NSStringFromClass([AppDelegate class]);
    }
    @try {
        return UIApplicationMain(argc, argv, nil, appDelegateClassName);
    } @catch (NSException *exception) {
        NSString *crashInfo = [NSString stringWithFormat:@"Exception: %@\nReason: %@\nStack:\n%@",
                               exception.name,
                               exception.reason,
                               [exception.callStackSymbols componentsJoinedByString:@"\n"]];
        [[NSUserDefaults standardUserDefaults] setObject:crashInfo forKey:@"AniAngliaLastCrash"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        @throw;
    }
}
