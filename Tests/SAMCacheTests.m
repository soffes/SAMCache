//
//  SAMCacheTests.m
//  SAMCacheTests
//
//  Created by Sam Soffes on 9/15/13.
//  Copyright (c) 2013-2014 Sam Soffes. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "SAMCache.h"

@interface SAMCache (Private)
@property (nonatomic, readonly) NSCache *cache;
@end

@interface SAMCacheTests : XCTestCase

@property (nonatomic) SAMCache *cache;

@end

@implementation SAMCacheTests

@synthesize cache = _cache;

- (void)setUp {
	self.cache = [[SAMCache alloc] initWithName:@"test" directory:nil];
}


- (void)tearDown {
	[self.cache removeAllObjects];
}


- (void)testReadingAndWriting {
	[self.cache setObject:@42 forKey:@"answer"];
	XCTAssertEqualObjects(@42, [self.cache objectForKey:@"answer"], @"Reading from memory cache");

	// Reset memory cache
	[self.cache.cache removeAllObjects];

	XCTAssertEqualObjects(@42, [self.cache objectForKey:@"answer"], @"Reading from disk cache");
}


- (void)testDeleting {
	[self.cache setObject:@2 forKey:@"deleting"];
	[self.cache removeObjectForKey:@"deleting"];
	XCTAssertNil([self.cache objectForKey:@"deleting"], @"Reading deleted object");
}


- (void)testSettingNilDeletes {
	[self.cache setObject:@3 forKey:@"niling"];
	[self.cache setObject:nil forKey:@"niling"];
	XCTAssertNil([self.cache objectForKey:@"niling"], @"Reading nil'd object");
}


- (void)testSettingWithSubscript {
	self.cache[@"subscriptSet"] = @"subset";
	XCTAssertEqualObjects(@"subset", [self.cache objectForKey:@"subscriptSet"], @"Setting an object with a subscript");
}


- (void)testReadingWithSubscript {
	[self.cache setObject:@"subread" forKey:@"subscriptRead"];
	XCTAssertEqualObjects(@"subread", self.cache[@"subscriptRead"], @"Reading an object with a subscript");
}

- (void)testAddingToDiskCacheOnly {
    [self.cache setObject:@42 forKey:@"answer" diskCacheOnly:YES];
    
    XCTAssertNil([self.cache.cache objectForKey:@"answer"]);
    
    XCTAssertEqualObjects(@42, [self.cache objectForKey:@"answer"], @"Reading from disk cache");
    
    XCTAssertNotNil([self.cache.cache objectForKey:@"answer"]);
}

- (void)testAddingToDiskCacheOnlyWithCallback {
    XCTestExpectation *diskWriteExpectation = [self expectationWithDescription:@"object written to disk"];
    
    __weak SAMCacheTests *weakSelf = self;
    
    [weakSelf.cache setObject:@42 forKey:@"answer" diskCacheOnly:YES withCompletion:^(BOOL didSave) {
        XCTAssert(didSave);
        [diskWriteExpectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testFlushMemoryCache {
    [self.cache setObject:@42 forKey:@"answer"];
    XCTAssertEqualObjects(@42, [self.cache objectForKey:@"answer"], @"Reading from memory cache");
    
    [self.cache flushMemoryCache];
    
    XCTAssertNil([self.cache.cache objectForKey:@"answer"]);
    
    XCTAssertEqualObjects(@42, [self.cache objectForKey:@"answer"], @"Reading from disk cache");
    
    XCTAssertNotNil([self.cache.cache objectForKey:@"answer"]);
}

@end
