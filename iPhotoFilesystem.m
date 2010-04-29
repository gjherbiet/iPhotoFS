/*
 iPhotoFilesystem.m
 iMediaBrowse
 
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


#import <sys/xattr.h>
#import <sys/stat.h>
#import <MacFUSE/MacFUSE.h>
#import "iPhotoFilesystem.h"
#import "WatchDog.h"

#define TEST_ALBUM_PATH  nil
// #define TEST_ALBUM_PATH  ([NSHomeDirectory() stringByAppendingString: @"/ExtAlbumData.xml"])
@implementation iPhotoFilesystem


// NOTE: It is fine to remove the below sections that are marked as 'Optional'.

// The core set of file system operations. This class will serve as the delegate
// for GMUserFileSystemFilesystem. For more details, see the section on 
// GMUserFileSystemOperations found in the documentation at:
// http://macfuse.googlecode.com/svn/trunk/core/sdk-objc/Documentation/index.html

#pragma mark Directory Contents

- (id) init
{
	if (self = [super init]) {
		
		[self parsePhotos];
		
	}
	return self;
}


- (NSMutableDictionary *) folderForKey: (NSString *) iPhotoKey  nameKey: (NSString *) nameKey idKey: (NSString *) idKey
{
	if (!iPhotoKey || !nameKey || !idKey) {
		return nil;
	}
	NSArray * listOfFolders = [_iPhotoDatabase objectForKey: iPhotoKey];

	NSMutableDictionary *folderDictionary = [[[NSMutableDictionary alloc] init] autorelease];

	NSEnumerator * enumerator = [listOfFolders objectEnumerator];
	NSDictionary * current;
	while (current = [enumerator nextObject])
	{
		NSString *name = [current objectForKey: nameKey];
		
		// see if we need to strip hi characters
		bool stripHiChars = false;
		for (int i=0, len = name.length; i < len; i++) {
			if ([name characterAtIndex: i] > 128) {
				stripHiChars = true;
				break;
			}
		}
		
		if (stripHiChars) {
			name = [NSMutableString stringWithString: name];
			CFStringNormalize((CFMutableStringRef)name, kCFStringNormalizationFormD);
		}
	
		if ([name rangeOfString: @" "].location >= 0) {
			// replace spaces with underscores for command line friendliness
			name = [name stringByReplacingOccurrencesOfString: @" " withString: @"_"];
		}
				
		
		/*if (stripHiChars) {
			NSMutableString *s = [[NSMutableString alloc] init];
			for (int i=0; i < name.length; i++) {
				unsigned char ch = [name characterAtIndex: i];
				if (ch > 128) {
					[s appendString: @"?"];
				} else {
					[s appendFormat: @"%c", ch];
				}
			}
			name = s;
		}
		
		
		name = [NSString stringWithCString: [name UTF8String]];
		*/
		
		if ([folderDictionary valueForKey: name]) {
			// name collision, uniquify the name with the roll ID
			name = [NSString stringWithFormat: @"%@_%@", name, [current objectForKey: idKey]];
		}
		[current setValue: name forKey: nameKey];
		
				
		NSString * albumType= [current valueForKey: @"Album Type"];
		NSString * parent = [current valueForKey:@"Parent"];
		NSLog(@"Album Name: %@, Album type: %@, Parent: %@", name, albumType, parent);
		
		if (parent == NULL) {
			[folderDictionary setValue: current forKey: name ];
			if ([iPhotoKey isEqualTo:@"List of Albums"]) {
				//NSLog(@"Album Name: %@, Album type: %@", name, albumType);
			}
		}
		
	} // end loop through albums
	
	return folderDictionary;
}

- (NSString *) libraryPath
{
	if (_libraryPath) {
		return _libraryPath;
	}
	// debugging
	
	NSString *libraryPath = nil;                                                                    
	
	NSString *testAlbumPath = TEST_ALBUM_PATH;
	
	if (testAlbumPath) {
		libraryPath = [testAlbumPath copy]; 
	} else {
		
		NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];                                     

		NSDictionary* appPrefs = [ud persistentDomainForName:@"com.apple.iApps"];                       

		NSArray *dbs = [appPrefs objectForKey:@"iPhotoRecentDatabases"];                                
		if ([dbs count] > 0) {                                                                          
			NSURL *url = [NSURL URLWithString:[dbs objectAtIndex:0]];                                   
			if ([url isFileURL]) {                                                                      
				libraryPath = [[url path] copy];                                                        
			}                                                                                           
		}                                                                                               

		if (!libraryPath) {                                                                             
			libraryPath = [[NSHomeDirectory() stringByAppendingString:                                  
							@"/Pictures/iPhoto Library/AlbumData.xml"]                                 
						   copy];                                                                      
		}
	}
	
	
	_libraryPath = libraryPath;
	return _libraryPath;
}

- (void)parsePhotos
{
	_iPhotoDatabase = [[NSDictionary alloc] initWithContentsOfFile: [self libraryPath]];
	_rootDict = [[NSMutableDictionary alloc] init];
	
	NSString * iPhotoVersionString = [_iPhotoDatabase objectForKey:@"Application Version"];
	int majorVersion = [iPhotoVersionString intValue];
	// ------------------------------------------
	// cache information about all of the albums
	
	NSArray * listOfAlbums = [_iPhotoDatabase objectForKey:@"List of Albums"];
	NSEnumerator * imageEnumerator = [listOfAlbums objectEnumerator];
	
	_dateDict = [[NSMutableDictionary alloc] init];
	[_rootDict setObject:  [self folderForKey: @"List of Albums" nameKey: @"AlbumName" idKey: @"AlbumId"] forKey: @"Albums"];
	if (majorVersion >= 7) {
		[_rootDict setObject: [self folderForKey: @"List of Rolls" nameKey: @"RollName" idKey: @"RollID"] forKey: @"Rolls"];
	} else {
		[_rootDict setObject: [self folderForKey: @"List of Rolls" nameKey: @"AlbumName" idKey: @"AlbumID"] forKey: @"Rolls"];
	}
	[_rootDict setObject: _dateDict forKey: @"Dates"];
	
	_imageDict = [_iPhotoDatabase objectForKey:@"Master Image List"];
	[_imageDict retain];
		 
	_imageNameDict = [[NSMutableDictionary alloc] init];
	imageEnumerator = [_imageDict keyEnumerator];
	id key;
	while ((key = [imageEnumerator nextObject])) {
		NSDictionary *image = [_imageDict objectForKey: key];
		NSString *path = [image objectForKey: @"ImagePath"];
		NSString *name= [path lastPathComponent];
		if (!name) { continue; }
		
		NSNumber *dateInterval = [image objectForKey: @"DateAsTimerInterval"];
		if (!dateInterval) { continue; }
		
		NSDate *date = [NSDate dateWithTimeIntervalSinceReferenceDate: [dateInterval intValue]];
		[self addImageKey: key forDate: date];
		
		if ([_imageNameDict objectForKey: name]) {
			// name collision, uniquify the name with the roll ID
			name = [NSString stringWithFormat: @"%@.%@", [image objectForKey: @"Roll"], name];
		}
		[image setValue: name forKey: @"ImageName"];

		[_imageNameDict setValue: image forKey: name];
	}	

}

- (NSMutableDictionary *) folderForDate: (NSDate *) date
{
	if (!date) {
		return nil;
	}
	NSString *dateFolderName = [date descriptionWithCalendarFormat:@"%Y-%m" timeZone:nil
								 locale:[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]];
	
	NSMutableDictionary *dateFolder = [_dateDict objectForKey: dateFolderName];
	if (!dateFolder) {
		dateFolder = [[NSMutableDictionary alloc] init];
		[_dateDict setValue: dateFolder forKey: dateFolderName];
		[dateFolder setObject: [[NSMutableArray alloc] init] forKey: @"KeyList"];
	}
	return dateFolder;
}

- (NSMutableArray *) keyListForDate: (NSDate *) date
{
	return [[self folderForDate: date] objectForKey: @"KeyList"];
}	

- (void) addImageKey: (NSString *)key forDate: (NSDate *) date
{
	[[self keyListForDate: date] addObject: key];
}


- (void) dealloc
{
	[_imageDict release]; 
	[_rootDict release];
	[_iPhotoDatabase release];
	[_dateDict release];
	[_libraryPath release];
	[super dealloc];
}

- (NSDictionary *)libraryNodeForPath: (NSString *)path
{
	NSArray *pathComponents = [path pathComponents];
	
	if (pathComponents.count < 1) {
		return nil;
	}
	
	NSDictionary *node = _rootDict;
	
	// look up each path component, starting  at 1 to skip "/"
	for (int i=1, count = [pathComponents count]; i < count; i++) {
		NSString *pathComponent = [pathComponents objectAtIndex: i];
		NSArray *keylist = [node objectForKey: @"KeyList"];
		if (keylist) {
			node = [_imageNameDict objectForKey: pathComponent];
		} else {
			node = [node objectForKey: pathComponent];
		}
	}
	return node;
}
	
	
- (NSString *)fileNameForPath: (NSString *)path
{
	NSDictionary *node = [self libraryNodeForPath: path];
	NSString *result = node ? [NSString stringWithCString: [[node objectForKey: @"ImagePath"] UTF8String] encoding: NSUTF8StringEncoding] : nil;
	return result;
}		

- (NSArray *)contentsOfDirectoryAtPath:(NSString *)path 
                                 error:(NSError **)error 
{
	NSDictionary *node = [self libraryNodeForPath: path];
	
	NSArray *keylist = [node objectForKey: @"KeyList"];
	if (keylist) {
		NSMutableArray *contents = [[NSMutableArray alloc] init];
		NSEnumerator * keyEnumerator = [keylist objectEnumerator];
		NSString *currentKey;
		while (currentKey = [keyEnumerator nextObject]) {
			NSDictionary *image = [_imageDict objectForKey: currentKey];
			NSString *imageName = [image objectForKey: @"ImageName"];
			[contents addObject: imageName];
		}
		return contents;
	} else {
		return [[node allKeys] sortedArrayUsingSelector:@selector(compare:)];
	}
}

#pragma mark Getting Attributes

- (NSDictionary *)attributesOfItemAtPath:(NSString *)path userData:(id)ud error:(NSError **)error
{
	/*
	NSString* p = [rootPath_ stringByAppendingString:path];
	NSDictionary* attribs = [[NSFileManager defaultManager] attributesOfItemAtPath:p error:error];
	return attribs;
	*/
	NSDictionary *node = [self libraryNodeForPath: path];
	if (!node) {
		return nil;
	}

	NSArray *pathComponents = [path pathComponents];   
	BOOL isDirectory = [node objectForKey: @"MediaType"] == nil;
	
	if (isDirectory) {
		
		// look up the attributes of the first image
		NSDictionary* attribs = nil;
		NSArray *keys = [node objectForKey: @"KeyList"];
		if ([keys count] > 0) {
			NSDictionary *child = [_imageDict objectForKey: [keys objectAtIndex: 0]];
			attribs =[[NSFileManager defaultManager] attributesOfItemAtPath: [child objectForKey: @"ImagePath"] error: nil] ;
			
		}
		
		NSDictionary *result = [NSDictionary dictionaryWithObjectsAndKeys:
				/* [NSNumber numberWithInt:mode], NSFilePosixPermissions,
				[NSNumber numberWithInt:geteuid()], NSFileOwnerAccountID,
				[NSNumber numberWithInt:getegid()], NSFileGroupOwnerAccountID, */
				attribs ? [attribs objectForKey: NSFileCreationDate] : [NSDate date] , NSFileCreationDate,
				attribs ? [attribs objectForKey: NSFileModificationDate] : [NSDate date], NSFileModificationDate, 
				NSFileTypeDirectory, NSFileType,
				nil]; 
		return result;
	} else if (![[pathComponents objectAtIndex: 1] isEqual: @"System"]) {
		NSString *p = [self fileNameForPath: path];
		NSDictionary* result = p ? [[NSFileManager defaultManager] attributesOfItemAtPath: p error:error] : nil;
		return result;
	} else {
		return nil;
	}
}

 - (NSDictionary *)attributesOfFileSystemForPath:(NSString *)path
                                          error:(NSError **)error 
{
    NSDictionary* d =[[NSFileManager defaultManager] attributesOfFileSystemForPath: @"/" error:error];
	return d;
}
 

- (NSArray *)extendedAttributesOfItemAtPath:(NSString *)path error:(NSError **)error {
	NSString *p = [self fileNameForPath: path];
	if (!p) return nil;
	
	
	ssize_t size = listxattr([p UTF8String], nil, 0, 0);
	if ( size < 0 ) {
		*error = [NSError errorWithPOSIXCode:errno];
		return nil;
	}
	NSMutableData* data = [NSMutableData dataWithLength:size];
	size = listxattr([p UTF8String], [data mutableBytes], [data length], 0);
	if ( size < 0 ) {
		*error = [NSError errorWithPOSIXCode:errno];
		return nil;
	}
	NSMutableArray* contents = [NSMutableArray array];
	char* ptr = (char *)[data bytes];
	while ( ptr < ((char *)[data bytes] + size) ) {
		NSString* s = [NSString stringWithUTF8String:ptr];
		[contents addObject:s];
		ptr += ([s length] + 1);
	}
	return contents;
}

 - (NSData *)valueOfExtendedAttribute:(NSString *)name 
                        ofItemAtPath:(NSString *)path
                            position:(off_t)position
                               error:(NSError **)error {  
	NSString *p = [self fileNameForPath: path];
	if (!p) return nil;
	
	ssize_t size = getxattr([p UTF8String], [name UTF8String], nil, 0,
							position, 0);
	if ( size < 0 ) {
		*error = [NSError errorWithPOSIXCode:errno];
		return nil;
	}
	NSMutableData* data = [NSMutableData dataWithLength:size];
	size = getxattr([p UTF8String], [name UTF8String], 
					[data mutableBytes], [data length],
					position, 0);
	if ( size < 0 ) {
		*error = [NSError errorWithPOSIXCode:errno];
		return nil;
	} 
	
	return data;
}

#pragma mark File Contents
- (BOOL)openFileAtPath:(NSString *)path 
                  mode:(int)mode
              userData:(id *)userData
                 error:(NSError **)error {
	NSString* p = [self fileNameForPath: path];
	int fd = open([p UTF8String], mode);
	if ( fd < 0 ) {
		*error = [NSError errorWithPOSIXCode:errno];
		return NO;
	}
	*userData = [NSNumber numberWithLong:fd];
	return YES;
}

- (void)releaseFileAtPath:(NSString *)path userData:(id)userData {
	NSNumber* num = (NSNumber *)userData;
	int fd = [num longValue];
	close(fd);
}

- (int)readFileAtPath:(NSString *)path 
             userData:(id)userData
               buffer:(char *)buffer 
                 size:(size_t)size 
               offset:(off_t)offset
                error:(NSError **)error 
{
	NSNumber* num = (NSNumber *)userData;
	int fd = [num longValue];
	int ret = pread(fd, buffer, size, offset);
	if ( ret < 0 ) {
		*error = [NSError errorWithPOSIXCode:errno];
		return -1;
	}
	return ret;
}

/*
#pragma mark Symbolic Links (Optional)

- (NSString *)destinationOfSymbolicLinkAtPath:(NSString *)path
                                        error:(NSError **)error {
	*error = [NSError errorWithPOSIXCode:ENOENT];
	return NO;
}
 */

/*
#pragma mark FinderInfo and ResourceFork (Optional)

- (NSDictionary *)finderAttributesAtPath:(NSString *)path 
                                   error:(NSError **)error {
	NSDictionary* attribs = nil;
	if ([self videoAtPath:path]) {
		NSNumber* finderFlags = [NSNumber numberWithLong:kHasCustomIcon];
		attribs = [NSDictionary dictionaryWithObject:finderFlags
											  forKey:kGMUserFileSystemFinderFlagsKey];
	}
	return attribs;
}


- (NSDictionary *)resourceAttributesAtPath:(NSString *)path
                                     error:(NSError **)error 
{
	NSMutableDictionary* attribs = nil;
	YTVideo* video = [self videoAtPath:path];
	if (video) {
		attribs = [NSMutableDictionary dictionary];
		NSURL* url = [video playerURL];
		if (url) {
			[attribs setObject:url forKey:kGMUserFileSystemWeblocURLKey];
		}
		url = [video thumbnailURL];
		if (url) {
			NSImage* image = [[[NSImage alloc] initWithContentsOfURL:url] autorelease];
			NSData* icnsData = [image icnsDataWithWidth:256];
			[attribs setObject:icnsData forKey:kGMUserFileSystemCustomIconDataKey];
		}
	}
	return attribs;  
}
*/




@end


@implementation iPhotoFilesystemWithReloading

- (id) init
{
	if (self = [super init]) {
		_lock = [[NSLock alloc] init];
		_lastReparseTime = nil;
		
		[self reload];
		[[Watchdog sharedWatchdog] watchLibrary: self]; 
	}
	return self;
}

- (iPhotoFilesystem *) fileSystem
{
	[_lock lock];
	iPhotoFilesystem *result = _iPhotoFileSystem;
	[_lock unlock];
	return result;	
}

- (void)reload                                                                                      
{
	const int minimumReparseInterval = 5;
	NSDate *date = [NSDate dateWithTimeIntervalSinceNow: -minimumReparseInterval];
	
	if (!_lastReparseTime || [_lastReparseTime compare: date] < 0) { 
		iPhotoFilesystem *newFileSystem = [[iPhotoFilesystem alloc] init];
		
		[_lock lock];
		[_iPhotoFileSystem release];
		_iPhotoFileSystem = newFileSystem;
		[_lastReparseTime release];
		_lastReparseTime = [[NSDate alloc] init];
		[_lock unlock];
	} 
}

- (NSString *) libraryPath
{
	return [[self fileSystem] libraryPath];
}

- (void) dealloc                                                                                    
{                                                                                                   
    [[Watchdog sharedWatchdog] forgetLibrary:self];                                                 
    [_iPhotoFileSystem release];                                                                              
	[_lock release];
	[_lastReparseTime release];
	
    [super dealloc];                                                                                
}   

- (NSArray *)contentsOfDirectoryAtPath:(NSString *)path error:(NSError **)error
{
	return [[self fileSystem] contentsOfDirectoryAtPath: path error: error];
}

- (NSDictionary *)attributesOfItemAtPath:(NSString *)path userData:(id) ud error:(NSError **)error
{
	return [[self fileSystem] attributesOfItemAtPath: path userData: ud error: error];
}

- (NSDictionary *)attributesOfFileSystemForPath:(NSString *)path error:(NSError **)error
{
	return [[self fileSystem] attributesOfFileSystemForPath: path error: error];	
}
- (NSData *)valueOfExtendedAttribute:(NSString *)name 
                        ofItemAtPath:(NSString *)path
                            position:(off_t)position
                               error:(NSError **)error
{
	return [[self fileSystem] valueOfExtendedAttribute:name	ofItemAtPath:path  position: position error: error];
}

- (BOOL)openFileAtPath:(NSString *)path 
                  mode:(int)mode
              userData:(id *)userData
                 error:(NSError **)error
{
	return [[self fileSystem] openFileAtPath:path mode:mode	userData: userData error: error];
}

- (void)releaseFileAtPath:(NSString *)path userData:(id)userData
{
	return [[self fileSystem] releaseFileAtPath: path userData: userData];
}

- (int)readFileAtPath:(NSString *)path 
             userData:(id)userData
               buffer:(char *)buffer 
                 size:(size_t)size 
               offset:(off_t)offset
                error:(NSError **)error
{
	return [[self fileSystem] readFileAtPath: path userData:userData buffer:buffer size:size offset:offset error:error];
}


- (NSString *)destinationOfSymbolicLinkAtPath:(NSString *)path
                                        error:(NSError **)error
{
	return [[self fileSystem] destinationOfSymbolicLinkAtPath: path error: error];
}


/*
- (NSData *) contentsAtPath: (NSString *) path
{
	return [[self fileSystem] contentsAtPath: path];
}
*/
@end





