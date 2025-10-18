//
//  QSUIAccessPlugIn_Source.m
//  QSUIAccessPlugIn
//
//  Created by Nicholas Jitkoff on 9/25/04.
//  Copyright __MyCompanyName__ 2004. All rights reserved.
//
#import "QSUIAccessPlugIn_Action.h"
#import "QSUIAccessPlugIn_Source.h"

@implementation QSUIAccessPlugIn_Source
- (NSString *)identifierForObject:(id <QSObject>)object{
  return nil;
}

// Object Handler Methods

- (void)setQuickIconForObject:(QSObject *)object{
    if ([[object primaryType] isEqualToString:kWindowsType]) {
        [object setIcon:[QSResourceManager imageNamed:@"WindowIcon"]];
    } else {
        [object setIcon:[QSResourceManager imageNamed:@"Object"]]; // An icon that is either already in memory or easy to load
    }
}

-(BOOL)loadIconForObject:(QSObject *)object {
    if (![[object primaryType] isEqualToString:kWindowsType]) {
        // other types don't have fancy icons (quick icon will do)
        return YES;
    }
    NSRunningApplication *process = [object objectForType:kWindowsProcessType];
    NSArray *appWindowDicts = WindowDictsForApp(process);
    SInt32 windowID = [object objectForCache:kWindowID] != nil ? [(NSNumber*)[object objectForCache:kWindowID] intValue] : -1;
	BOOL __block successful = NO;
	[appWindowDicts enumerateObjectsWithOptions:NSEnumerationConcurrent usingBlock:^(NSDictionary *info, NSUInteger idx, BOOL * _Nonnull stop) {
		if (windowID != -1) {
                if ([[info objectForKey:(NSString *)kCGWindowNumber] intValue] != windowID) {
                    return;
                }
                // It's possible the window name has changed (e.g. in because we have changed its content)
                [object setName:(NSString*)[info objectForKey:(NSString *)kCGWindowName]];
        } else {
            NSString *windowName = (NSString*)[info objectForKey:(NSString *)kCGWindowName];
            if (!windowName || [windowName localizedCompare:[object name]] != 0) {
                return;
            }
        }
        CGRect bounds;
        CGRectMakeWithDictionaryRepresentation((CFDictionaryRef)[info objectForKey:(NSString *)kCGWindowBounds],&bounds);
        if (bounds.size.width < 1 || bounds.size.height < 1) {
            return;
        }
        
        CGImageRef windowImage = CGWindowListCreateImage(CGRectNull, kCGWindowListOptionIncludingWindow, [[info objectForKey:(NSString*)kCGWindowNumber] unsignedIntValue], kCGWindowImageBoundsIgnoreFraming);
        if (!windowImage) {
            return;
        }
        if (![object objectForCache:kWindowID]) {
            [object setObject:[info objectForKey:(NSString *)kCGWindowNumber] forCache:kWindowID];
        }
        NSImage *icon = [[NSImage alloc] initWithCGImage:windowImage size:NSZeroSize];
        [object setIcon:icon];
        [icon release];
        CGImageRelease(windowImage);
        *stop = YES;
		successful = YES;
		return;
	}];
    return successful;
}

- (BOOL)objectHasChildren:(QSObject *)object{
	id element=[object objectForType:kQSUIElementType];
	CFIndex count=0;
	AXUIElementGetAttributeValueCount((AXUIElementRef)element, kAXChildrenAttribute, &count);
	return count;
}

- (NSString *)detailsOfObject:(QSObject *)object{
  return nil;
}

- (NSArray *)childrenForElement:(AXUIElementRef)element{
	CFIndex count=0;
	NSArray *children=nil;
	AXUIElementGetAttributeValueCount(element, kAXChildrenAttribute, &count);
	AXUIElementCopyAttributeValues(element, kAXChildrenAttribute, 0, count, (CFArrayRef *)&children);
	return [children autorelease];
}

- (NSArray *)objectsForElements:(NSArray *)elements parent:(AXUIElementRef)parent process:(NSRunningApplication *)process {
	if (!elements)return nil;
	NSMutableArray *objects=[NSMutableArray arrayWithCapacity:[elements count]];
    NSString *parentName = nil;
    AXUIElementCopyAttributeValue((AXUIElementRef)parent, kAXTitleAttribute, (CFTypeRef *)&parentName);
    @autoreleasepool {
        for(NSString * element in elements){
            NSString *name = nil;
            AXUIElementCopyAttributeValue ((AXUIElementRef)element, kAXTitleAttribute, (CFTypeRef *)&name);
            [name autorelease];
            //NSLog(@"name %@",name);
            if (![name length]) continue;
            
            QSObject *object=[QSObject objectForUIElement:element name:name parent:parentName process:process];
            [objects addObject:object];		
        }
    }
    [parentName release];
	return objects;
}

- (BOOL)loadChildrenForObject:(QSObject *)object{
    AXUIElementRef element = (AXUIElementRef)[object objectForType:kQSUIElementType];
	NSArray *children = [self childrenForElement:element];
    NSRunningApplication *process = [object objectForType:kWindowsProcessType];
	[object setChildren:[self objectsForElements:children parent:element process:process]];
	return YES;
}

@end


QSObject * QSObjectForAXUIElementWithNameProcessType(id element, NSString *name, NSString *parentName, NSRunningApplication *process, NSString *type)
{
    if (!name) {
        NSString *newName = nil;
        if (AXUIElementCopyAttributeValue((AXUIElementRef)element, kAXTitleAttribute, (CFTypeRef *)&newName) != kAXErrorSuccess) return nil;
        if (AXValueGetType((AXValueRef)newName) == kAXValueAXErrorType) return nil;
        [newName autorelease];
        name = newName;
    }
    QSObject *object = [[QSObject alloc] init];
    if (parentName != nil) {
        NSString *fullPath = [NSString stringWithFormat:@"%@ ▸ %@", parentName, name];
        [object setDetails:fullPath];
        [object setName:fullPath];
        [object setLabel:name];
    } else {
        [object setName:name];
    }
    // give items an identifier, so mnemonics can be saved
    [object setIdentifier:[NSString stringWithFormat:@"bundle:%@:name:%@ ▸ %@", [process bundleIdentifier], parentName, name]];
	[object setObject:element forType:type];
    [object setPrimaryType:type];
	[object setObject:process forType:kWindowsProcessType];
	return object;
}

@implementation QSObject (UIElement)
+ (QSObject *)objectForUIElement:(id)element name:(NSString *)name parent:(NSString *)parentName process:(NSRunningApplication *)process
{
    QSObject *object = QSObjectForAXUIElementWithNameProcessType(element, name, parentName, process, kQSUIElementType);
    NSImage *icon = [process icon];
    if (icon) {
        [object setIcon:icon];
    }
    return object;
}
@end

@implementation QSObject (Windows)
+ (QSObject *)objectForWindow:(id)element name:(NSString *)name process:(NSRunningApplication *)process appWindows:(NSArray *)appWindows {
    QSObject *object = QSObjectForAXUIElementWithNameProcessType(element, name, nil, process, kWindowsType);
    [object setPrimaryType:kWindowsType];
    return object;
}
@end

