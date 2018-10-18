//
//  main.m
//  jailfree-service
//
//  Created by Lukas Pitschl on 28.09.12.
//
//

#include <Foundation/Foundation.h>
#include "GPGGlobals.h"
#include "JailfreeTask.h"

@interface JailfreeService : NSObject <NSXPCListenerDelegate>
@end

@implementation JailfreeService

- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection {
    newConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(Jailfree)];
    
    
    JailfreeTask *exportedObject = [[JailfreeTask alloc] init];
    newConnection.exportedObject = exportedObject;
    
    newConnection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(Jail)];
    exportedObject.xpcConnection = newConnection;
    
    [newConnection resume];
    return YES;
}

@end

int main(int argc, const char *argv[])
{
    NSXPCListener *serviceListener = [[NSXPCListener alloc] initWithMachServiceName:JAILFREE_XPC_MACH_NAME];
    
    JailfreeService *delegate = [[JailfreeService alloc] init];
    serviceListener.delegate = delegate;
    
    [serviceListener resume];
    [[NSRunLoop currentRunLoop] run];
    
    return 0;
}
