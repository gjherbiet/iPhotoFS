/*
 iPhoto_Controller.m
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

#import <MacFUSE/MacFUSE.h>
#import "iPhotoFS_Controller.h"
#import "iPhotoFilesystem.h"

@implementation iPhotoFSController

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
	NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
	[center addObserver:self selector:@selector(mountFailed:)
				   name:kGMUserFileSystemMountFailed object:nil];
	[center addObserver:self selector:@selector(didMount:)
				   name:kGMUserFileSystemDidMount object:nil];
	[center addObserver:self selector:@selector(didUnmount:)
				   name:kGMUserFileSystemDidUnmount object:nil];
	
	NSString* mountPath = @"/Volumes/iphotofs";
	fs_delegate_ = [[iPhotoFilesystemWithReloading alloc] init];
	fs_ = [[GMUserFileSystem alloc] initWithDelegate:fs_delegate_ isThreadSafe: NO];
	
	NSMutableArray* options = [NSMutableArray array];
	NSString* volArg = [NSString stringWithFormat:@"volicon=%@", [[NSBundle mainBundle] pathForResource:@"iphotofs" ofType:@"icns"]];
	[options addObject:volArg];
	[options addObject:@"volname=iphotofs"];
	[options addObject:@"rdonly"];
	[options addObject:@"allow_other"];
	[options addObject:@"local"];

	[fs_ mountAtPath:mountPath withOptions:options];
}

- (void)didMount:(NSNotification *)notification {
	NSDictionary* userInfo = [notification userInfo];
	NSString* mountPath = [userInfo objectForKey:kGMUserFileSystemMountPathKey];
	NSString* parentPath = [mountPath stringByDeletingLastPathComponent];
	[[NSWorkspace sharedWorkspace] selectFile:mountPath
					 inFileViewerRootedAtPath:parentPath];
}

- (void)mountFailed:(NSNotification *)notification {
  NSDictionary* userInfo = [notification userInfo];
  NSError* error = [userInfo objectForKey:kGMUserFileSystemErrorKey];
  NSLog(@"kGMUserFileSystem Error: %@, userInfo=%@", error, [error userInfo]);  
  NSRunAlertPanel(@"Mount Failed", [error localizedDescription], nil, nil, nil);
  [[NSApplication sharedApplication] terminate:nil];
}


- (void)didUnmount:(NSNotification*)notification {
  [[NSApplication sharedApplication] terminate:nil];
}


- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [fs_ unmount];
  [fs_ release];
  [fs_delegate_ release];
  return NSTerminateNow;
}

@end
