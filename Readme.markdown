# SYCache

Simple in memory and on disk cache. It's backed by an [NSCache](https://developer.apple.com/library/mac/#documentation/Cocoa/Reference/NSCache_Class/Reference/Reference.html) in memory, so it automatically purges itself when memory gets low. Purged memory keys will automatically be loaded from disk the next time the are requested.

## Usage

The API is simple.

``` objective-c
- (id)objectForKey:(NSString *)key;
- (void)objectForKey:(NSString *)key usingBlock:(void (^)(id object))block;
- (void)setObject:(id)object forKey:(NSString *)key;
```

See [SYCache.h](https://github.com/Synthetic/SYCache/blob/master/SYCache.h) for the full list of methods.

## Adding to Your Project

Simply add `SYCache.h` and `SYCache.m` to your project.

### ARC

If you are including SYCache in a project that not uses [Automatic Reference Counting (ARC)](http://clang.llvm.org/docs/AutomaticReferenceCounting.html), you will need to set the `-fobjc-arc` compiler flag on all of the SYCache source files. To do this in Xcode, go to your active target and select the "Build Phases" tab. In the "Compiler Flags" column, set `-fobjc-arc` for each of the SYCache source files.
