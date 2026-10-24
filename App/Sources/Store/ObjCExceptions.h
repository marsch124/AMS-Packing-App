// The app's one piece of Objective-C (24 Oct 2026, crash A), and the bridging header that hands it
// to Swift. Some of Apple's frameworks report trouble by THROWING an Objective-C exception, which
// Swift cannot catch: SwiftData reading a photo's bytes from a file that is not there throws
// "External data reference can't find underlying file." On his Mac (0.99) that throw ran out
// through the Swift code that was reading the store, the Mac app swallowed it and went on with
// Swift's own bookkeeping broken — and the next click, six minutes later, shut the app. Caught
// here, where it is thrown, it is a photo not read this time and nothing more.
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Runs `work`. An Objective-C exception it throws is caught here and handed back; nil = none was.
NSException * _Nullable AMSCatchException(NS_NOESCAPE void (^work)(void));

NS_ASSUME_NONNULL_END
