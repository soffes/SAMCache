//
//  SSCache.m
//  SSCache
//
//  Created by Sam Soffes on 10/31/11.
//  Copyright (c) 2011-2013 Sam Soffes. All rights reserved.
//

#import "SSCache.h"

// Conditional for dispatch_release from AFNetowkring. Thanks Mattt!
#if TARGET_OS_IPHONE
	#if __IPHONE_OS_VERSION_MIN_REQUIRED >= 60000   // iOS 6.0 or later
		#define NEEDS_DISPATCH_RETAIN_RELEASE 0
	#else                                           // iOS 5.X or earlier
		#define NEEDS_DISPATCH_RETAIN_RELEASE 1
	#endif
#else
	#if MAC_OS_X_VERSION_MIN_REQUIRED >= 1080       // Mac OS X 10.8 or later
		#define NEEDS_DISPATCH_RETAIN_RELEASE 0
	#else
		#define NEEDS_DISPATCH_RETAIN_RELEASE 1     // Mac OS X 10.7 or earlier
	#endif
#endif

@interface SSCache (Private)
- (NSString *)_pathForKey:(NSString *)key;
@end

@implementation SSCache {
	NSCache *_cache;
	dispatch_queue_t _queue;
	NSFileManager *_fileManager;
	NSString *_cacheDirectory;
}

@synthesize name = _name;

#pragma mark - NSObject

- (id)init {
	NSLog(@"[SSCache] You must initalize SSCache using `initWithName:`.");
	return nil;
}


- (void)dealloc {
	[_cache removeAllObjects];

#if NEEDS_DISPATCH_RETAIN_RELEASE
  dispatch_release(_queue);
#endif
}


#pragma mark - Getting the Shared Cache

+ (SSCache *)sharedCache {
	static SSCache *sharedCache = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedCache = [[SSCache alloc] initWithName:@"com.samsoffes.sscache.shared"];
	});
	return sharedCache;
}


#pragma mark - Initializing


- (id)initWithName:(NSString *)name {
	if ((self = [super init])) {
		_name = [name copy];

		_cache = [[NSCache alloc] init];
		_cache.name = name;

		_queue = dispatch_queue_create([name cStringUsingEncoding:NSUTF8StringEncoding], DISPATCH_QUEUE_SERIAL);

		_fileManager = [[NSFileManager alloc] init];
		NSString *cachesDirectory = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
		_cacheDirectory = [cachesDirectory stringByAppendingFormat:@"/com.samsoffes.sscache/%@", name];

		if (![_fileManager fileExistsAtPath:_cacheDirectory]) {
			[_fileManager createDirectoryAtPath:_cacheDirectory withIntermediateDirectories:YES attributes:nil error:nil];
		}
	}
	return self;
}


#pragma mark - Getting a Cached Value

- (id)objectForKey:(NSString *)key {
	__block id object = [_cache objectForKey:key];
	if (object) {
		return object;
	}

	// Get path if object exists
	NSString *path = [self pathForKey:key];
	if (!path) {
		return nil;
	}

	// Load object from disk
	object = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
	if (!object) {
		// Object was removed from disk before we could read it
		return nil;
	}

	// Store in cache
	[_cache setObject:object forKey:key];

	return object;
}


- (void)objectForKey:(NSString *)key usingBlock:(void (^)(id object))block {
	dispatch_sync(_queue, ^{
		id object = [_cache objectForKey:key];
		if (!object) {
			object = [NSKeyedUnarchiver unarchiveObjectWithFile:[self _pathForKey:key]];
			[_cache setObject:object forKey:key];
		}

    __block id blockObject = object;
		block(blockObject);
	});
}


- (BOOL)objectExistsForKey:(NSString *)key {
	__block BOOL exists = ([_cache objectForKey:key] != nil);
	if (exists) {
		return YES;
	}

	dispatch_sync(_queue, ^{
		exists = [_fileManager fileExistsAtPath:[self _pathForKey:key]];
	});
	return exists;
}


#pragma mark - Adding and Removing Cached Values

- (void)setObject:(id)object forKey:(NSString *)key {
	if (!object) {
		return;
	}

	dispatch_async(_queue, ^{
		NSString *path = [self _pathForKey:key];

		// Stop if in memory cache or disk cache
	    id cachedObject = [_cache objectForKey:key];
	    if ( [cachedObject isEqual:object] && [_fileManager fileExistsAtPath:path]) {
	      return;
	    }


		// Save to memory cache
		[_cache setObject:object forKey:key];

		// Save to disk cache
		[NSKeyedArchiver archiveRootObject:object toFile:[self _pathForKey:key]];
	});
}


- (void)removeObjectForKey:(id)key {
	[_cache removeObjectForKey:key];

	dispatch_async(_queue, ^{
		[_fileManager removeItemAtPath:[self _pathForKey:key] error:nil];
	});
}


- (void)removeAllObjects {
	[_cache removeAllObjects];

	dispatch_async(_queue, ^{
		for (NSString *path in [_fileManager contentsOfDirectoryAtPath:_cacheDirectory error:nil]) {
			[_fileManager removeItemAtPath:[_cacheDirectory stringByAppendingPathComponent:path] error:nil];
		}
	});
}


#pragma mark - Accessing the Disk Cache

- (NSString *)pathForKey:(NSString *)key {
	if ([self objectExistsForKey:key]) {
		return [self _pathForKey:key];
	}
	return nil;
}


#pragma mark - Private
//Remove illegals "Filename" Characters from the filename String
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

	return [_cacheDirectory stringByAppendingPathComponent:key];
}
@end


#if TARGET_OS_IPHONE

@interface SSCache (UIImagePrivateAdditions)
+ (NSString *)_keyForImageKey:(NSString *)imageKey;
@end

@implementation SSCache (UIImageAdditions)

- (UIImage *)imageForKey:(NSString *)key {
	key = [[self class] _keyForImageKey:key];

	__block UIImage *image = [_cache objectForKey:key];
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
	[_cache setObject:image forKey:key];

	return image;
}


- (void)imageForKey:(NSString *)key usingBlock:(void (^)(UIImage *image))block {
	key = [[self class] _keyForImageKey:key];

	dispatch_sync(_queue, ^{
		UIImage *image = [_cache objectForKey:key];
		if (!image) {
			image = [[UIImage alloc] initWithContentsOfFile:[self _pathForKey:key]];
			[_cache setObject:image forKey:key];
		}
		__block UIImage *blockImage = image;
		block(blockImage);
	});
}


- (void)setImage:(UIImage *)image forKey:(NSString *)key {
	if (!image) {
		return;
	}

	key = [[self class] _keyForImageKey:key];

	dispatch_async(_queue, ^{
		NSString *path = [self _pathForKey:key];

		// Stop if in memory cache or disk cache
	    id cachedObject = [_cache objectForKey:key];
	    if ( [cachedObject isEqual:image] && [_fileManager fileExistsAtPath:path]) {
	      return;
	    }


		// Save to memory cache
		[_cache setObject:image forKey:key];

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
