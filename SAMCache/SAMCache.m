//
//  SAMCache.m
//  SAMCache
//
//  Created by Sam Soffes on 10/31/11.
//  Copyright (c) 2011-2014 Sam Soffes. All rights reserved.
//

#import "SAMCache.h"

@interface SAMCache ()
@property (nonatomic, readwrite) NSString *name;
@property (nonatomic, readwrite) NSString *directory;
@property (nonatomic) NSCache *cache;
@property (nonatomic, readonly) NSFileManager *fileManager;
@property (nonatomic) dispatch_queue_t callbackQueue;
@property (nonatomic) dispatch_queue_t diskQueue;
@end

@implementation SAMCache

#pragma mark - Accessors

@synthesize name = _name;
@synthesize directory = _directory;
@synthesize cache = _cache;
@synthesize fileManager = _fileManager;
@synthesize callbackQueue = _callbackQueue;
@synthesize diskQueue = _diskQueue;

- (NSCache *)cache {
	if (!_cache) {
		_cache = [[NSCache alloc] init];
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
		sharedCache = [[SAMCache alloc] initWithName:@"com.samsoffes.samcache.shared" directory:nil];
	});
	return sharedCache;
}


#pragma mark - Initializing

- (instancetype)initWithName:(NSString *)name {
	return [self initWithName:name directory:nil];
}

- (instancetype)initWithName:(NSString *)name directory:(NSString *)directory {
	NSParameterAssert(name);

	if ((self = [super init])) {
		self.name = [name copy];
		self.cache.name = self.name;
		self.callbackQueue = dispatch_queue_create([[name stringByAppendingString:@".callback"] cStringUsingEncoding:NSUTF8StringEncoding], DISPATCH_QUEUE_CONCURRENT);
		self.diskQueue = dispatch_queue_create([[name stringByAppendingString:@".disk"] cStringUsingEncoding:NSUTF8StringEncoding], DISPATCH_QUEUE_SERIAL);

		if (!directory) {
			NSString *cachesDirectory = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
			directory = [cachesDirectory stringByAppendingFormat:@"/com.samsoffes.samcache/%@", self.name];
		}
		self.directory = directory;

		if (![self.fileManager fileExistsAtPath:self.directory]) {
			NSError *error;
			[self.fileManager createDirectoryAtPath:self.directory withIntermediateDirectories:YES attributes:nil error:&error];

			if (error) {
				NSLog(@"Failed to create caches directory: %@", error);
			}
			else {
				[self _excludeFileFromBackup:[NSURL fileURLWithPath:self.directory]];
			}
		}
	}
	return self;
}


#pragma mark - Getting a Cached Value

- (id)objectForKey:(NSString *)key {
	NSParameterAssert(key);

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
	NSParameterAssert(key);
	NSParameterAssert(block);

	dispatch_async(self.callbackQueue, ^{
		block([self objectForKey:key]);
	});
}


- (BOOL)objectExistsForKey:(NSString *)key {
	NSParameterAssert(key);

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

- (void)setObject:(id <NSCoding>)object forKey:(NSString *)key {
	NSParameterAssert(key);

	// If there's no object, delete the key.
	if (!object) {
		[self removeObjectForKey:key];
		return;
	}

	// Save to memory cache
	[self.cache setObject:object forKey:key];

	dispatch_async(self.diskQueue, ^{
		// Save to disk cache
		NSString *path = [self _pathForKey:key];
		if ([NSKeyedArchiver archiveRootObject:object toFile:path]) {
			[self _excludeFileFromBackup:[NSURL fileURLWithPath:path]];
		}
	});
}


- (void)removeObjectForKey:(NSString *)key {
	NSParameterAssert(key);

	[self.cache removeObjectForKey:key];

	dispatch_async(self.diskQueue, ^{
		[self.fileManager removeItemAtPath:[self _pathForKey:key] error:nil];
	});
}


- (void)removeAllObjects {
	[self.cache removeAllObjects];

	dispatch_async(self.diskQueue, ^{
		for (NSString *path in [self.fileManager contentsOfDirectoryAtPath:self.directory error:nil]) {
			[self.fileManager removeItemAtPath:[self.directory stringByAppendingPathComponent:path] error:nil];
		}
		[self.fileManager removeItemAtPath:self.directory error:nil];
	});
}


#pragma mark - Accessing the Disk Cache

- (NSString *)pathForKey:(NSString *)key {
	NSParameterAssert(key);

	if ([self objectExistsForKey:key]) {
		return [self _pathForKey:key];
	}
	return nil;
}


#pragma mark - Subscripting

- (id)objectForKeyedSubscript:(NSString *)key {
	NSParameterAssert(key);

	return [self objectForKey:(NSString *)key];
}


- (void)setObject:(id <NSCoding>)object forKeyedSubscript:(NSString *)key {
	NSParameterAssert(key);

	[self setObject:object forKey:key];
}


#pragma mark - Private

- (NSString *)_sanitizeFileNameString:(NSString *)fileName {
	NSParameterAssert(fileName);

	static NSCharacterSet *illegalFileNameCharacters = nil;
	static dispatch_once_t illegalCharacterCreationToken;
	dispatch_once(&illegalCharacterCreationToken, ^{
		illegalFileNameCharacters = [NSCharacterSet characterSetWithCharactersInString: @"\\?%*|\"<>:"];
	});

	return [[fileName componentsSeparatedByCharactersInSet:illegalFileNameCharacters] componentsJoinedByString:@""];
}


- (NSString *)_pathForKey:(NSString *)key {
	NSParameterAssert(key);

	key = [self _sanitizeFileNameString: key];
	return [self.directory stringByAppendingPathComponent:key];
}

- (BOOL)_excludeFileFromBackup:(NSURL *)fileUrl {
	NSParameterAssert(fileUrl);
	NSParameterAssert([[NSFileManager defaultManager] fileExistsAtPath:[fileUrl path]]);

	NSError *error;
	BOOL result = [fileUrl setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:&error];
	if (error) {
		NSLog(@"Failed to exclude file from backup: %@", error);
	}
	return result;
}

@end


#if TARGET_OS_IPHONE

#import <UIKit/UIScreen.h>

@implementation SAMCache (UIImageAdditions)

- (NSString *)imagePathForKey:(NSString *)key {
    NSParameterAssert(key);
    
	key = [[self class] _keyForImageKey:key];
    NSString *path = [self pathForKey:key];
    return path;
}

- (UIImage *)imageForKey:(NSString *)key {
	NSParameterAssert(key);

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
	NSParameterAssert(key);
	NSParameterAssert(block);

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
	NSParameterAssert(key);

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


- (BOOL)imageExistsForKey:(NSString *)key {
	NSParameterAssert(key);
	return [self objectExistsForKey:[[self class] _keyForImageKey:key]];
}


- (void)removeImageForKey:(NSString *)key {
	NSParameterAssert(key);
	[self removeObjectForKey:[[self class] _keyForImageKey:key]];
}


#pragma mark - Private

+ (NSString *)_keyForImageKey:(NSString *)imageKey {
	NSParameterAssert(imageKey);
    CGFloat screenScale = [[UIScreen mainScreen] scale];
    NSString *scale = @"@3x";
    if(screenScale == 2.0f){
        scale = @"@2x";
    }else if(screenScale == 1.0f){
        scale = @"";
    }
	return [imageKey stringByAppendingFormat:@"%@.png", scale];
}

@end

#endif
