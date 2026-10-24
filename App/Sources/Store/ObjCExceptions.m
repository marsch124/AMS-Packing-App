#import "ObjCExceptions.h"

NSException * _Nullable AMSCatchException(NS_NOESCAPE void (^work)(void)) {
    @try {
        work();
    } @catch (NSException *exception) {
        return exception;
    }
    return nil;
}
