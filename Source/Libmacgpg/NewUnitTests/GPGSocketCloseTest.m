//
//  GPGSocketCloseTest.m
//  Libmacgpg
//
//  Created by Lukas Pitschl on 04.07.15.
//
//

#import <XCTest/XCTest.h>
#import <Foundation/Foundation.h>
#import <sys/proc.h>
#import <sys/sysctl.h>
#import <sys/proc.h>
#import <sys/proc_info.h>
#import <libproc.h>
#import "Libmacgpg.h"
#import "GPGUnitTest.h"
#import "GPGTaskHelper.h"



@interface GPGSocketCloseTest : XCTestCase
@end

@implementation GPGSocketCloseTest


+ (void)setUp {
	[GPGUnitTest setUpTestDirectory];
}


- (uid_t)uidFromPid:(pid_t)pid {
	uid_t uid = -1;
	
	struct kinfo_proc process;
	size_t procBufferSize = sizeof(process);
	
	// Compose search path for sysctl. Here you can specify PID directly.
	const u_int pathLenth = 4;
	int path[pathLenth] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, pid};
	
	int sysctlResult = sysctl(path, pathLenth, &process, &procBufferSize, NULL, 0);
	
	// If sysctl did not fail and process with PID available - take UID.
	if ((sysctlResult == 0) && (procBufferSize != 0)) {
		uid = process.kp_eproc.e_ucred.cr_uid;
	}
	
	return uid;
}


- (NSInteger)pidForProcessWithName:(NSString *)name {
	NSMutableArray *ret = [NSMutableArray arrayWithCapacity:1];
	
	int numberOfProcesses = proc_listpids(PROC_ALL_PIDS, 0, NULL, 0);
	pid_t pids[1024];
	bzero(pids, 1024);
	proc_listpids(PROC_ALL_PIDS, 0, pids, sizeof(pids));
	for (int i = 0; i < numberOfProcesses; ++i) {
		if (pids[i] == 0) { continue; }
		char pathBuffer[PROC_PIDPATHINFO_MAXSIZE];
		bzero(pathBuffer, PROC_PIDPATHINFO_MAXSIZE);
		proc_pidpath(pids[i], pathBuffer, sizeof(pathBuffer));
		
		NSMutableDictionary *process = [[NSMutableDictionary alloc] init];
		
		process[@"pid"] = @(pids[i]);
		process[@"uid"] = @([self uidFromPid:pids[i]]);
		process[@"name"] = [@(pathBuffer) lastPathComponent];
		
		[ret addObject:process];
	}

	
	unsigned int current_user_id = getuid();
	
	NSInteger pid = -1;
	for(NSDictionary *process in ret) {
		// Skip processes that don't belong to the current user.
		if([process[@"uid"] integerValue] != current_user_id)
			continue;
		if([process[@"name"] isEqualToString:name])
			pid = [process[@"pid"] integerValue];
	}
	
	return pid;
}

- (NSArray *)openSocketConnectionForPid:(NSInteger)pid {
	int i, nb, nf;
	struct proc_fdinfo *fdp;
	struct proc_taskallinfo tai;
	
	NSMutableArray *sockets = [NSMutableArray array];
	
	static struct proc_fdinfo *Fds = (struct proc_fdinfo *)NULL;
	/* FD buffer */
	static int NbFds = 0;				/* bytes allocated to FDs */
	
	nb = proc_pidinfo((int)pid, PROC_PIDTASKALLINFO, 0, &tai, sizeof(tai));
	int n = tai.pbsd.pbi_nfiles;
	
	/*
	 * Make sure an FD buffer has been allocated.
	 */
	if (!Fds) {
		NbFds = sizeof(struct proc_fdinfo) * n;
		Fds = (struct proc_fdinfo *)malloc(NbFds);
	} else if (NbFds < sizeof(struct proc_fdinfo) * n) {
		
		/*
		 * More proc_fdinfo space is required.  Allocate it.
		 */
		NbFds = sizeof(struct proc_fdinfo) * n;
		Fds = (struct proc_fdinfo *)realloc((void *)Fds,
											NbFds);
	}
	/*
	 * Get FD information for the process.
	 */
	nb = proc_pidinfo((int)pid, PROC_PIDLISTFDS, 0, Fds, NbFds);
	if (nb <= 0) {
		if (errno == ESRCH) {
			
			/*
			 * Quit if no FD information is available for the process.
			 */
			return nil;
		}
	}
	nf = (int)(nb / sizeof(struct proc_fdinfo));
	/*
	 * Loop through the file descriptors.
	 */
	for (i = 0; i < nf; i++) {
		fdp = &Fds[i];
		int fd = fdp->proc_fd;
		
		if(fdp->proc_fdtype != PROX_FDTYPE_SOCKET)
			continue;
		
		struct socket_fdinfo si;
		nb = proc_pidfdinfo((int)pid, fd, PROC_PIDFDSOCKETINFO, &si, sizeof(si));
		// Not necessary to add any error code, since the test will simply fail if an error occurs.
		
		int fam = si.psi.soi_family;
		if(fam != AF_UNIX)
			continue;
		if (si.psi.soi_kind != SOCKINFO_UN)
			continue;
		
		int unl;
		if (si.psi.soi_proto.pri_un.unsi_addr.ua_sun.sun_path[0]) {
			unl = si.psi.soi_proto.pri_un.unsi_addr.ua_sun.sun_len - offsetof(struct sockaddr_un, sun_path);
			if ((unl < 0) || (unl >= sizeof(si.psi.soi_proto.pri_un.unsi_addr.ua_sun.sun_path)))
				unl = sizeof(si.psi.soi_proto.pri_un.unsi_addr.ua_sun.sun_path) - 1;
			si.psi.soi_proto.pri_un.unsi_addr.ua_sun.sun_path[unl] = '\0';
			
			[sockets addObject:@{@"sunPath": @(si.psi.soi_proto.pri_un.unsi_addr.ua_sun.sun_path)}];
		}
	}
	
	
	return sockets;
}

- (NSInteger)numberOfOpenSocketConnections {
	NSArray *sockets = [self openSocketConnectionForPid:[self pidForProcessWithName:@"gpg-agent"]];
	NSInteger nrOfSockets = 0;
	for(NSDictionary *socket in sockets) {
		if(![[socket[@"sunPath"] lastPathComponent] isEqualToString:@"S.gpg-agent"])
			continue;
		nrOfSockets++;
	}
	return nrOfSockets;
}


// This test doens't work with gpg >= 2.1 anymore, because the passphrase does not get into the cache, when passed via passphrase-fd!
- (void)testPassphraseInAgentSocketCloseBug {
	// Calling isPassphraseForKeyInGPGAgentCache: seems to trigger a bug where the socket connection
	// which is established to the gpg-agent is not always closed.
	// This test will only pass if all sockets are properly closed after usage.
	
	// In order to warm the passphrase cache some random data is signed.
	NSString *content = @"This content is signed to warm up the passphrase cache.";
	NSData *contentData = [content dataUsingEncoding:NSUTF8StringEncoding];
	
	gpgc.useArmor = YES;
	gpgc.useTextMode = YES;
	// Automatically trust keys, even though they are not specifically
	// marked as such.
	// Eventually add warning for this.
	gpgc.trustAllKeys = YES;
	
	GPGKey *signerKey = [[GPGKeyManager sharedInstance].allKeys member:testKey2];
	XCTAssert(signerKey != nil, @"For this test to run properly, it's necessary to have at least one secret key.");
	
	gpgc.signerKey = signerKey;
	
	NSData *signedContent = [gpgc processData:contentData withEncryptSignMode:GPGSign recipients:nil hiddenRecipients:nil];
	XCTAssertNil(gpgc.error, @"Error occured while signing data: %@", gpgc.error);
	XCTAssertNotNil(signedContent, @"Failed to sign data");
	
	NSInteger currentNumberOfOpenSocketConnections = [self numberOfOpenSocketConnections];
	
	int maxRuns = 300;
	int i = 0;
	for(; i < 300; i++) {
		BOOL inCache = [GPGTaskHelper isPassphraseInGPGAgentCache:signerKey.fingerprint];
		if(!inCache) {
			if(i > 0 && i < maxRuns - 1) {
				XCTFail(@"Number of available FDs probably exhausted. Bug caught!");
			}
			else {
				XCTFail(@"The passphrase has to be cached in order for the bug to reveal itself.");
			}
			break;
		}
	}
	XCTAssert([self numberOfOpenSocketConnections] == currentNumberOfOpenSocketConnections, @"What now, a connection still open? Houston, we have a bug");
}

@end
