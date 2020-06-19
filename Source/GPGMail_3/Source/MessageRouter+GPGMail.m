/* MessageRouter+GPGMail.m created by Lukas Pitschl (@lukele) on Fri 29-Jul-2013 */

/*
 * Copyright (c) 2000-2013, GPGTools Team <team@gpgtools.org>
 * All rights reserved.
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of GPGTools nor the names of GPGMail
 *       contributors may be used to endorse or promote products
 *       derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE GPGTools Team ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE GPGTools Team BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "MessageRouter+GPGMail.h"
#import "MFMessageCriterion.h"
#import "NSObject+LPDynamicIvars.h"
#import "NSArray+Functional.h"
#import "MFMessageRule.h"

@implementation MessageRouter_GPGMail

+ (void)MAPutRulesThatWantsToHandleMessage:(id)message intoArray:(id)rules colorRulesOnly:(BOOL)colorRulesOnly {
	[self MAPutRulesThatWantsToHandleMessage:message intoArray:rules colorRulesOnly:colorRulesOnly];
	
	// Not triggered by ourselves to handle encrypted and signed message related rules?
	// Out of here!
	if(![message getIvar:@"OnlyIncludeEncryptedAndSignedRules"])
		return;
	
	// Only keep the rules which evaluate the encrypted or signed flag.
	NSArray *encryptedOrSignedRules = [rules filter:^MFMessageRule *(MFMessageRule *rule) {
		BOOL criteriaMatches = NO;
		for(MFMessageCriterion *criterion in rule.criteria) {
			if(criterion.criterionType == 18 || criterion.criterionType == 19) {
				criteriaMatches = YES;
				break;
			}
		}
		
		return criteriaMatches ? rule : nil;
	}];
	
	// Usually it might be dangerous to remove all objects
	// Remove all rules and only re-add those that are handling
	// encrypted and|or signed messages.
	[rules removeAllObjects];
	[rules addObjectsFromArray:encryptedOrSignedRules];
	
	[message removeIvar:@"OnlyIncludeEncryptedAndSignedRules"];
	
	return;
}

@end
