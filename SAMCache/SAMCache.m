//
//  SAMCache.m
//  SAMCache
//
//  Created by Sam Soffes on 10/31/11.
//  Copyright (c) 2011-2013 Sam Soffes. All rights reserved.
//

#import "SAMCache.h"

@interface SAMCache ()
@property (nonatomic, readwrite) NSString *name;
@property (nonatomic) NSCache *cache;
@property (nonatomic) NSString *cacheDirectory;
@property (nonatomic, readonly) NSFileManager *fileManager;
@property (nonatomic) dispatch_queue_t callbackQueue;
@property (nonatomic) dispatch_queue_t diskQueue;
@end

@implementation SAMCache

#pragma mark - Accessors

@synthesize name = _name;
@synthesize cache = _cache;
@synthesize cacheDirectory = _cacheDirectory;
@synthesize fileManager = _fileManager;
@synthesize callbackQueue = _callbackQueue;
@synthesize diskQueue = _diskQueue;

- (NSCache *)cache {
	if (!_cache) {
		_cache = [[NSCache alloc] init];;
	}
	return _cache;
}


- (NSFileManager *)fileManager {
	if (!_fileManager) {
		_fileManager = [[NSFileManager alloc] init];
	}
	return _fileManager;
}


#pragma mark - NSObject

- (id)init {
	NSLog(@"[SAMCache] You must initalize SAMCache using `initWithName:`.");
	return nil;
}


- (void)dealloc {
	[self.cache removeAllObjects];
}


#pragma mark - Getting the Shared Cache

+ (SAMCache *)sharedCache {
	static SAMCache *sharedCache = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedCache = [[SAMCache alloc] initWithName:@"com.samsoffes.samcache.shared"];
	});
	return sharedCache;
}


#pragma mark - Initializing

- (instancetype)initWithName:(NSString *)name {
	if ((self = [super init])) {
		self.name = [name copy];
		self.cache.name = self.name;
		self.callbackQueue = dispatch_queue_create([[name stringByAppendingString:@".callback"] cStringUsingEncoding:NSUTF8StringEncoding], DISPATCH_QUEUE_CONCURRENT);
		self.diskQueue = dispatch_queue_create([[name stringByAppendingString:@".disk"] cStringUsingEncoding:NSUTF8StringEncoding], DISPATCH_QUEUE_SERIAL);

		NSString *cachesDirectory = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
		self.cacheDirectory = [cachesDirectory stringByAppendingFormat:@"/com.samsoffes.samcache/%@", self.name];

		if (![self.fileManager fileExistsAtPath:self.cacheDirectory]) {
			[self.fileManager createDirectoryAtPath:self.cacheDirectory withIntermediateDirectories:YES attributes:nil error:nil];
		}
	}
	return self;
}


#pragma mark - Getting a Cached Value

- (id)objectForKey:(NSString *)key {
	// Look for the object in the memory cache.
	__block id object = [self.cache objectForKey:key];
	if (object) {
		return object;
	}

	// See if the object has a path on disk.
	NSString *path = [self pathForKey:key];
	if (!path) {
		return nil;
	}

	dispatch_sync(self.diskQueue, ^{
		// Load object from disk, synchronously.
		object = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
		if (!object) {
			// Object was removed from disk before we could read it.
			return;
		}
	});

	// Store the object from disk in the memory cache.
	if (object) {
		[self.cache setObject:object forKey:key];
	}

	return object;
}


- (void)objectForKey:(NSString *)key usingBlock:(void (^)(id <NSCopying> object))block {
	if (!block) {
		return;
	}

	dispatch_async(self.callbackQueue, ^{
		block([self objectForKey:key]);
	});
}


- (BOOL)objectExistsForKey:(NSString *)key {
	__block BOOL exists = [self.cache objectForKey:key] != nil;
	if (exists) {
		return YES;
	}

	dispatch_sync(self.diskQueue, ^{
		exists = [self.fileManager fileExistsAtPath:[self _pathForKey:key]];
	});
	return exists;
}


#pragma mark - Adding and Removing Cached Values

- (void)setObject:(id <NSCopying>)object forKey:(NSString *)key {
	// Invalid without a key
	if (!key) {
		return;
	}

	// If there's no object, delete the key.
	if (!object) {
		[self removeObjectForKey:key];
		return;
	}

	// Save to memory cache
	[self.cache setObject:object forKey:key];

	dispatch_sync(self.diskQueue, ^{
		// Save to disk cache
		[NSKeyedArchiver archiveRootObject:object toFile:[self _pathForKey:key]];
	});
}


- (void)removeObjectForKey:(NSString *)key {
	[self.cache removeObjectForKey:key];

	dispatch_async(self.diskQueue, ^{
		[self.fileManager removeItemAtPath:[self _pathForKey:key] error:nil];
	});
}


- (void)removeAllObjects {
	[self.cache removeAllObjects];

	dispatch_async(self.diskQueue, ^{
		for (NSString *path in [self.fileManager contentsOfDirectoryAtPath:self.cacheDirectory error:nil]) {
			[self.fileManager removeItemAtPath:[self.cacheDirectory stringByAppendingPathComponent:path] error:nil];
		}
	});
}

- (void)unloadAllObjects {
	[self.cache removeAllObjects];
}


#pragma mark - Accessing the Disk Cache

- (NSString *)pathForKey:(NSString *)key {
	if ([self objectExistsForKey:key]) {
		return [self _pathForKey:key];
	}
	return nil;
}


#pragma mark - Subscripting

- (id)objectForKeyedSubscript:(NSString *)key {
	return [self objectForKey:(NSString *)key];
}


- (void)setObject:(id <NSCopying>)object forKeyedSubscript:(NSString *)key {
	[self setObject:object forKey:key];
}


#pragma mark - Private

//Remove illegals "Filename" Characters from the filename string
- (NSString *)_sanitizeFileNameString:(NSString *)fileName {
  static NSCharacterSet *illegalFileNameCharacters = nil;

	static dispatch_once_t illegalCharacterCreationToken;
	dispatch_once(&illegalCharacterCreationToken, ^{
		illegalFileNameCharacters = [NSCharacterSet characterSetWithCharactersInString: @"/\\?%*|\"<>:/" ];
	});

  if (!illegalFileNameCharacters) {
    return fileName;
  }

	return [ [fileName componentsSeparatedByCharactersInSet: illegalFileNameCharacters] componentsJoinedByString: @""];
}


- (NSString *)_pathForKey:(NSString *)key {
	key = [self _sanitizeFileNameString: key];
	return [self.cacheDirectory stringByAppendingPathComponent:key];
}

@end


#if TARGET_OS_IPHONE

#import <UIKit/UIScreen.h>

@implementation SAMCache (UIImageAdditions)

- (UIImage *)imageForKey:(NSString *)key {
	key = [[self class] _keyForImageKey:key];

	__block UIImage *image = [self.cache objectForKey:key];
	if (image) {
		return image;
	}

	// Get path if object exists
	NSString *path = [self pathForKey:key];
	if (!path) {
		return nil;
	}

	// Load object from disk
	image = [UIImage imageWithContentsOfFile:path];

	// Store in cache
	[self.cache setObject:image forKey:key];

	return image;
}


- (void)imageForKey:(NSString *)key usingBlock:(void (^)(UIImage *image))block {
	key = [[self class] _keyForImageKey:key];

	dispatch_sync(self.diskQueue, ^{
		UIImage *image = [self.cache objectForKey:key];
		if (!image) {
			image = [[UIImage alloc] initWithContentsOfFile:[self _pathForKey:key]];
			[self.cache setObject:image forKey:key];
		}
		__block UIImage *blockImage = image;
		block(blockImage);
	});
}


- (void)setImage:(UIImage *)image forKey:(NSString *)key {
	// Invalid without a key
	if (!key) {
		return;
	}

	// If there's no image, delete the key.
	if (!image) {
		[self removeObjectForKey:key];
		return;
	}

	key = [[self class] _keyForImageKey:key];

	dispatch_async(self.diskQueue, ^{
		NSString *path = [self _pathForKey:key];

		// Save to memory cache
		[self.cache setObject:image forKey:key];

		// Save to disk cache
		[UIImagePNGRepresentation(image) writeToFile:path atomically:YES];
	});
}


#pragma mark - Private

+ (NSString *)_keyForImageKey:(NSString *)imageKey {
	NSString *scale = [[UIScreen mainScreen] scale] == 2.0f ? @"@2x" : @"";
	return [imageKey stringByAppendingFormat:@"%@.png", scale];
}

@end

#endif
