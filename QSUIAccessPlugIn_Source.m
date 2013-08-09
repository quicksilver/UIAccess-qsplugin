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
    [object setIcon:[QSResourceManager imageNamed:@"Object"]]; // An icon that is either already in memory or easy to load
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

- (NSArray *)objectsForElements:(NSArray *)elements process:(NSRunningApplication *)process {
	if (!elements)return nil;
	NSMutableArray *objects=[NSMutableArray arrayWithCapacity:[elements count]];
    @autoreleasepool {
        for(NSString * element in elements){
            NSString *name = nil;
            AXUIElementCopyAttributeValue ((AXUIElementRef)element, kAXTitleAttribute, (CFTypeRef *)&name);
            [name autorelease];
            //NSLog(@"name %@",name);
            if (![name length]) continue;
            QSObject *object=[QSObject objectForUIElement:element name:name process:process];
            [objects addObject:object];		
        }
    }
	return objects;
}

- (BOOL)loadChildrenForObject:(QSObject *)object{
    AXUIElementRef element = (AXUIElementRef)[object objectForType:kQSUIElementType];
	NSArray *children = [self childrenForElement:element];
    NSRunningApplication *process = [object objectForType:kWindowsProcessType];
	[object setChildren:[self objectsForElements:children process:process]];
	return YES;
}

@end


QSObject * QSObjectForAXUIElementWithNameProcessType(id element, NSString *name, NSRunningApplication *process, NSString *type)
{
    if (!name) {
        NSString *newName = nil;
        if (AXUIElementCopyAttributeValue((AXUIElementRef)element, kAXTitleAttribute, (CFTypeRef *)&newName) != kAXErrorSuccess) return nil;
        if (AXValueGetType((AXValueRef)newName) == kAXValueAXErrorType) return nil;
        [newName autorelease];
        name = newName;
    }
    
    QSObject *object = [QSObject objectWithName:name];
	[object setObject:element forType:type];
	[object setObject:process forType:kWindowsProcessType];
	return object;
}

@implementation QSObject (UIElement)
+ (QSObject *)objectForUIElement:(id)element name:(NSString *)name process:(NSRunningApplication *)process
{
    QSObject *object = QSObjectForAXUIElementWithNameProcessType(element, name, process, kQSUIElementType);
    NSImage *icon = [process icon];
    if (icon) {
        [object setIcon:icon];
    }
    return object;
}
@end

@implementation QSObject (Windows)
+ (QSObject *)objectForWindow:(id)element name:(NSString *)name process:(NSRunningApplication *)process appWindows:(NSArray *)appWindows
{
    QSObject *object = QSObjectForAXUIElementWithNameProcessType(element, name, process, kWindowsType);
    for (NSDictionary *info in appWindows) {
        NSString *windowName = (NSString*)[info objectForKey:(NSString *)kCGWindowName];
        if (!windowName) continue;
        if ([windowName localizedCompare:[object name]] != 0) continue;
        CGRect bounds;
        CGRectMakeWithDictionaryRepresentation((CFDictionaryRef)[info objectForKey:(NSString *)kCGWindowBounds],&bounds);
        if (NSWidth((NSRect)bounds) < 1 || NSHeight((NSRect)bounds) < 1) {
            continue;
        }
        
        CGImageRef windowImage = CGWindowListCreateImage(CGRectNull, kCGWindowListOptionIncludingWindow, [[info objectForKey:(NSString*)kCGWindowNumber] unsignedIntValue], kCGWindowImageBoundsIgnoreFraming);
        if (!windowImage) {
            continue;
        }
        NSImage *icon = [[NSImage alloc] initWithCGImage:windowImage size:NSZeroSize];
        [object setIcon:icon];
        [icon release];
        CGImageRelease(windowImage);
        break;
    }
    
    if (![object icon]) {
        [object setIcon:[QSResourceManager imageNamed:@"WindowIcon"]];
    }
    
    return object;
}
@end

