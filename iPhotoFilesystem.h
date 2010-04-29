/*
 iPhotoFilesystem.h
 Copyright [2009] by Phillip Bogle
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import <Cocoa/Cocoa.h>

@interface iPhotoFilesystem : NSObject {
	NSString *_libraryPath;
	NSDictionary *_iPhotoDatabase;
	NSMutableDictionary *_rootDict;
	NSDictionary *_imageDict;
	NSDictionary *_imageNameDict;
	NSDictionary *_dateDict;
}

- (id) init;
- (NSString *) libraryPath;
- (void)parsePhotos;
- (NSMutableDictionary *) folderForKey: (NSString *) iPhotoKey  nameKey: (NSString *) nameKey idKey: (NSString *) idKey;
- (NSMutableDictionary *) folderForDate: (NSDate *) date;
- (NSMutableArray *) keyListForDate: (NSDate *) date;
- (void) addImageKey: (NSString *)key forDate: (NSDate *) date;
- (void) dealloc;

- (NSArray *)contentsOfDirectoryAtPath:(NSString *)path error:(NSError **)error;
- (NSDictionary *)attributesOfItemAtPath:(NSString *)_path userData:(id)_ud error:(NSError **)error;
- (NSDictionary *)attributesOfFileSystemForPath:(NSString *)path error:(NSError **)error;
- (NSData *)valueOfExtendedAttribute:(NSString *)name 
                        ofItemAtPath:(NSString *)path
                            position:(off_t)position
                               error:(NSError **)error; 
	
- (BOOL)openFileAtPath:(NSString *)path 
                  mode:(int)mode
              userData:(id *)userData
                 error:(NSError **)error;
	
- (void)releaseFileAtPath:(NSString *)path userData:(id)userData;
- (int)readFileAtPath:(NSString *)path 
             userData:(id)userData
               buffer:(char *)buffer 
                 size:(size_t)size 
               offset:(off_t)offset
                error:(NSError **)error;

@end


@interface iPhotoFilesystemWithReloading : NSObject {
	iPhotoFilesystem *_iPhotoFileSystem;
	NSLock *_lock;
	NSDate *_lastReparseTime;
}
- (id) init;
- (NSString *) libraryPath;
- (void)reload;


- (NSArray *)contentsOfDirectoryAtPath:(NSString *)path error:(NSError **)error;
- (NSDictionary *)attributesOfItemAtPath:(NSString *)_path userData:(id)_ud error:(NSError **)error;
- (NSDictionary *)attributesOfFileSystemForPath:(NSString *)path error:(NSError **)error;
- (NSData *)valueOfExtendedAttribute:(NSString *)name 
                        ofItemAtPath:(NSString *)path
                            position:(off_t)position
                               error:(NSError **)error; 

- (BOOL)openFileAtPath:(NSString *)path 
                  mode:(int)mode
              userData:(id *)userData
                 error:(NSError **)error;

- (void)releaseFileAtPath:(NSString *)path userData:(id)userData;
- (int)readFileAtPath:(NSString *)path 
             userData:(id)userData
               buffer:(char *)buffer 
                 size:(size_t)size 
               offset:(off_t)offset
                error:(NSError **)error;
@end



// Category on NSError to  simplify creating an NSError based on posix errno.                                                            
@interface NSError (POSIX)                                                                                                               
+ (NSError *)errorWithPOSIXCode:(int)code;                                                                                               
@end                                                                                                                                     


