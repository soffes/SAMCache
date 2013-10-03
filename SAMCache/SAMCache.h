//
//  SAMCache.h
//  SAMCache
//
//  Created by Sam Soffes on 10/31/11.
//  Copyright (c) 2011-2013 Sam Soffes. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SAMCache : NSObject

/**
 The name of the cache.
 */
@property (nonatomic, readonly) NSString *name;

///-------------------------------
/// @name Getting the Shared Cache
///-------------------------------

/**
 Shared cache suitable for all of your caching needs.
 
 @return A shared cache.
 */
+ (SAMCache *)sharedCache;


///-------------------
/// @name Initializing
///-------------------

/**
 Initialize a separate cache from the shared cache. It may be handy to make a separate cache from the shared cache in
 case you need to call `removeAllObjects`.
 
 @param name A string to identify the cache.
 
 @return A new cache.
 */
- (instancetype)initWithName:(NSString *)name;


///-----------------------------
/// @name Getting a Cached Value
///-----------------------------

/**
 Synchronously get an object from the cache.

 @param key The key of the object.

 @return The object for the given key or `nil` if it does not exist.
 */
- (id)objectForKey:(NSString *)key;

/**
 Asynchronously get an object from the cache.

 @param key The key of the object.

 @param block A block called on an arbitrary queue with the requested object or `nil` if it does not exist.
 */
- (void)objectForKey:(NSString *)key usingBlock:(void (^)(id <NSCopying> object))block;

/**
 Synchronously check if an object exists in the cache without retriving it.
 
 @param key The key of the object.

 @return A boolean specifying if the object exists or not.
 */
- (BOOL)objectExistsForKey:(NSString *)key;


///----------------------------------------
/// @name Adding and Removing Cached Values
///----------------------------------------

/**
 Synchronously set an object in the cache for a given key.
 
 @param object The object to store in the cache.

 @param key The key of the object.
 */
- (void)setObject:(id <NSCopying>)object forKey:(NSString *)key;

/**
 Remove an object from the cache.
 
 @param key The key of the object.
 */
- (void)removeObjectForKey:(NSString *)key;

/**
 Remove all objects from the cache.
 */
- (void)removeAllObjects;

/**
 Remove all objects from the memory (but keep on disk).
 */
- (void)unloadAllObjects;


///-------------------------------
/// @name Accessing the Disk Cache
///-------------------------------

/**
 Returns the path to the object on disk associated with a given key.

 @param key An object identifying the value.

 @return Path to object on disk or `nil` if no object exists for the given `key`.
 */
- (NSString *)pathForKey:(NSString *)key;


///-------------------
/// @name Subscripting
///-------------------

/**
 Synchronously get an object from the cache.

 @param key The key of the object.

 @return The object for the given key or `nil` if it does not exist.
 
 This method behaves the same as `objectForKey:`.
 */
- (id)objectForKeyedSubscript:(NSString *)key;

/**
 Synchronously set an object in the cache for a given key.

 @param object The object to store in the cache.

 @param key The key of the object.
 
 This method behaves the same as `setObject:forKey:`.
 */
- (void)setObject:(id <NSCopying>)object forKeyedSubscript:(NSString *)key;

@end


#if TARGET_OS_IPHONE

#import <UIKit/UIImage.h>

@interface SAMCache (UIImageAdditions)

/**
 Synchronously get an image from the cache.

 @param key The key of the image.

 @return The image for the given key or `nil` if it does not exist.
 */
- (UIImage *)imageForKey:(NSString *)key;

/**
 Asynchronously get an image from the cache.

 @param key The key of the image.

 @param block A block called on an arbitrary queue with the requested image or `nil` if it does not exist.
 */
- (void)imageForKey:(NSString *)key usingBlock:(void (^)(UIImage *image))block;

/**
 Synchronously store a PNG representation of an image in the cache for a given key.

 @param image The image to store in the cache.

 @param key The key of the image.
 */
- (void)setImage:(UIImage *)image forKey:(NSString *)key;

@end

#endif
