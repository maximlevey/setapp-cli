#ifndef CBRIDGE_H
#define CBRIDGE_H

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#include <dlfcn.h>

NS_ASSUME_NONNULL_BEGIN

/// XPC protocol for Setapp's interprocess service interface.
///
/// Must be defined in Objective-C so the compiler embeds extended type
/// information that NSXPCInterface needs. The ObjC runtime's basic type
/// encoding '@?' for blocks doesn't include parameter types, so Swift-only
/// protocol definitions produce nil method signatures.
@protocol AFXRegularServiceInterface <NSObject>

- (void)performInterprocessRequest:(id)request
                   responseHandler:(void (^)(id _Nullable response))handler;

- (void)establishReportingStreamWithTierNamed:(NSString *)tier
                                     endpoint:(id)endpoint
                                     callback:(void (^)(id _Nullable response))callback;
@end

// MARK: - ObjC Helper Functions

/// Create an AFXRegularInterprocessClientAdaptor.
/// Wraps the 4-argument init that exceeds performSelector's limit.
static inline id _Nullable
CreateAdaptor(NSString *serviceName, NSString *tierName,
              NSSet *requestClasses, id _Nullable delegate) {
    Class cls = NSClassFromString(@"AFXRegularInterprocessClientAdaptor");
    if (!cls) return nil;

    SEL sel = @selector(initWithServiceName:tierName:requestClasses:delegate:);
    NSMethodSignature *sig = [cls instanceMethodSignatureForSelector:sel];
    if (!sig) return nil;

    id obj = [cls alloc];
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    [inv setTarget:obj];
    [inv setSelector:sel];
    [inv setArgument:&serviceName atIndex:2];
    [inv setArgument:&tierName atIndex:3];
    [inv setArgument:&requestClasses atIndex:4];
    [inv setArgument:&delegate atIndex:5];
    [inv invoke];

    __unsafe_unretained id result;
    [inv getReturnValue:&result];
    return result;
}

/// Create an AFXGlobalServiceID (fallback service ID).
static inline id _Nullable
CreateGlobalServiceID(NSString *serviceName) {
    Class cls = NSClassFromString(@"AFXGlobalServiceID");
    if (!cls) return nil;

    SEL sel = @selector(initWithServiceName:);
    NSMethodSignature *sig = [cls instanceMethodSignatureForSelector:sel];
    if (!sig) return nil;

    id obj = [cls alloc];
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    [inv setTarget:obj];
    [inv setSelector:sel];
    [inv setArgument:&serviceName atIndex:2];
    [inv invoke];

    __unsafe_unretained id result;
    [inv getReturnValue:&result];
    return result;
}

/// Call a setter that takes a scalar UInt64 (type encoding Q).
/// Swift's performSelector only passes objects, corrupting scalar fields.
static inline void
AFXSetScalarUInt64(id _Nonnull obj, SEL _Nonnull sel, uint64_t value) {
    void (*msgSend)(id, SEL, uint64_t) = (void (*)(id, SEL, uint64_t))objc_msgSend;
    msgSend(obj, sel, value);
}

/// Call a setter that takes a scalar BOOL (type encoding B).
static inline void
AFXSetScalarBool(id _Nonnull obj, SEL _Nonnull sel, BOOL value) {
    void (*msgSend)(id, SEL, BOOL) = (void (*)(id, SEL, BOOL))objc_msgSend;
    msgSend(obj, sel, value);
}

/// Send a request via the adaptor's 3-argument method.
/// Wraps performRequest:reportHandler:responseHandler: which has 2 block
/// arguments, exceeding performSelector's limit.
static inline void
AdaptorPerformRequest(id _Nonnull adaptor, id _Nonnull request,
                      void (^_Nonnull reportHandler)(id _Nullable report),
                      void (^_Nonnull responseHandler)(id _Nullable response)) {
    SEL sel = @selector(performRequest:reportHandler:responseHandler:);
    NSMethodSignature *sig = [adaptor methodSignatureForSelector:sel];
    if (!sig) {
        fprintf(stderr, "error: no method signature for performRequest:reportHandler:responseHandler:\n");
        return;
    }

    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    [inv setTarget:adaptor];
    [inv setSelector:sel];
    [inv setArgument:&request atIndex:2];
    [inv setArgument:&reportHandler atIndex:3];
    [inv setArgument:&responseHandler atIndex:4];
    [inv invoke];
}

NS_ASSUME_NONNULL_END

#endif
