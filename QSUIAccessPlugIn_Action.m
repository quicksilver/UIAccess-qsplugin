//
//  QSUIAccessPlugIn_Action.m
//  QSUIAccessPlugIn
//
//  Created by Nicholas Jitkoff on 9/25/04.
//  Copyright __MyCompanyName__ 2004. All rights reserved.
//

#import "QSUIAccessPlugIn_Action.h"

#import <ApplicationServices/ApplicationServices.h>
#import "QSUIAccessPlugIn_Source.h"

@implementation QSUIAccessPlugIn_Action


NSArray *MenuItemsForElement(AXUIElementRef element, NSInteger depth, NSString *elementName, NSString *parentName, NSInteger menuIgnoreDepth, NSRunningApplication *process) {
    NSUInteger childrenCount = 0;
    NSArray *children = nil;
    if (depth > 0) {
        // don't work out the children if we're not going any deeper
        AXUIElementCopyAttributeValue(element, kAXChildrenAttribute, (CFTypeRef *)&children);
        childrenCount = [children count];
    }
    if (depth < 1 || childrenCount < 1) {
        QSObject *menuObject = [QSObject objectForUIElement:(id)element name:elementName parent:parentName process:process];
        return (menuObject) ? [NSArray arrayWithObject:menuObject] : [NSArray array];
    }
    NSMutableOrderedSet *menuItems = [NSMutableOrderedSet new];
    NSString *_parentName = nil;
    AXUIElementCopyAttributeValue(element, kAXTitleAttribute, (CFTypeRef *)&_parentName);
    @autoreleasepool {
        for (id child in children) {
            CFTypeRef enabled = NULL;
            if (AXUIElementCopyAttributeValue((AXUIElementRef)child, kAXEnabledAttribute, &enabled) != kAXErrorSuccess) continue;
            [(id)enabled autorelease];
            if (!CFBooleanGetValue(enabled)) {
                continue;
            }

            NSString *name = nil;
            // try not to get the name attribute and test it unless we really have to
            if (AXUIElementCopyAttributeValue((AXUIElementRef)child, kAXTitleAttribute, (CFTypeRef *)&name) == kAXErrorSuccess)
            {
                [name autorelease];
# warning "Comparing name equality in English only will break localised apps"
                if ([name isEqualToString:@"Apple"] || [name isEqualToString:@"Services"])
                {
                    continue;
                }
            }
            [menuItems addObjectsFromArray:MenuItemsForElement((AXUIElementRef)child, depth - 1, name, _parentName != nil ? (parentName != nil ? [NSString stringWithFormat:@"%@ ▸ %@", parentName, _parentName] : _parentName) : parentName, menuIgnoreDepth - 1, process)];
        }
    }
    [_parentName release];
    [children release];
    
    return [[menuItems autorelease] array];
}

- (QSObject *)appMenus:(QSObject *)dObject pickItem:(QSObject *)iObject{
	return [self pickUIElement:iObject];
}	

- (BOOL)bypassValidation {
	NSDictionary *appDictionary = [[NSWorkspace sharedWorkspace] activeApplication];
	NSString *identifier = [appDictionary objectForKey:@"NSApplicationBundleIdentifier"];
	if ([identifier isEqualToString:kQSBundleID])
		return YES;
	else
		return NO;
}

- (QSObject *)searchAppMenus:(QSObject *)dObject{
  dObject = [self resolvedProxy:dObject];
    
    id process = [dObject objectForType:QSProcessType];
    if ([process isKindOfClass:[NSDictionary class]]) {
        // for when the main app turns to using NSRunningApplication class for 'QSProcessType'
        process = [NSRunningApplication runningApplicationWithProcessIdentifier:[[process objectForKey:@"NSApplicationProcessIdentifier"] intValue]];
    }
	AXUIElementRef app=AXUIElementCreateApplication ([process processIdentifier]);
	AXUIElementRef menuBar;
	AXUIElementCopyAttributeValue (app, kAXMenuBarAttribute, (CFTypeRef *)&menuBar);
    CFRelease(app);
	NSArray *items=MenuItemsForElement(menuBar, 6, nil, nil, 2, process);
    CFRelease(menuBar);
	[QSPreferredCommandInterface showArray:[[items mutableCopy] autorelease]];
	return nil;
}	

NSArray *WindowDictsForApp(NSRunningApplication *process) {
    // get a list of this application's windows
    CFArrayRef windows = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements, kCGNullWindowID);
    __block NSMutableArray *appWindowDicts = [NSMutableArray array];
    [(NSArray *)windows enumerateObjectsWithOptions:NSEnumerationConcurrent usingBlock:^(NSDictionary *info, NSUInteger idx, BOOL *stop) {
        if ([(NSNumber *)[info objectForKey:(NSString *)kCGWindowOwnerPID] intValue] == [process processIdentifier]) {
            [appWindowDicts addObject:info];
        }
    }];
    return [[appWindowDicts copy] autorelease];
}

NSArray *WindowsForApp(NSRunningApplication *process, BOOL appName)
{
	pid_t pid = [process processIdentifier];
    AXUIElementRef appElement = AXUIElementCreateApplication(pid);
    NSArray *appWindows = nil;
    AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute, (CFTypeRef *)&appWindows);
    CFRelease(appElement);
    __block NSMutableArray *windowObjects = [NSMutableArray array];
    NSArray *appWindowDicts = WindowDictsForApp(process);
    [appWindows enumerateObjectsWithOptions:NSEnumerationConcurrent usingBlock:^(id aWindow, NSUInteger idx, BOOL *stop) {
        NSString *windowTitle = nil;
        AXUIElementCopyAttributeValue((AXUIElementRef)aWindow, kAXTitleAttribute, (CFTypeRef *)&windowTitle);
        if (windowTitle) {
        [windowTitle autorelease];
            QSObject *object = [QSObject objectForWindow:aWindow name:windowTitle process:process appWindows:appWindowDicts];
            if (object) {
                if (appName) [object setName:[windowTitle stringByAppendingFormat:@" (%@)",[process localizedName]]];
                [object setObject:process forType:kWindowsProcessType];
                [windowObjects addObject:object];
            }
        }
    }];
    for (id aWindow in appWindows) {

    }
    [appWindows release];
    return windowObjects;
}

- (QSObject *)getWindowsForApp:(QSObject *)dObject
{
    dObject = [self resolvedProxy:dObject];
    id process = [dObject objectForType:QSProcessType];
    if ([process isKindOfClass:[NSDictionary class]]) {
        process = [NSRunningApplication runningApplicationWithProcessIdentifier:[[process objectForKey:@"NSApplicationProcessIdentifier"] intValue]];
    }
    NSArray *windowObjects = WindowsForApp(process, NO);
    if (windowObjects) {
        [QSPreferredCommandInterface showArray:[[windowObjects mutableCopy] autorelease]];
    }
    return nil;
}

- (QSObject *)focusedWindowForApp:(QSObject *)dObject{
    dObject = [self resolvedProxy:dObject];
    id process = [dObject objectForType:QSProcessType];
    if ([process isKindOfClass:[NSDictionary class]]) {
        process = [NSRunningApplication runningApplicationWithProcessIdentifier:[[process objectForKey:@"NSApplicationProcessIdentifier"] intValue]];
    }
    AXUIElementRef appElement = AXUIElementCreateApplication([process processIdentifier]);
    id focusedWindow = nil;
    AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute, (CFTypeRef *)&focusedWindow);
    CFRelease(appElement);
    [focusedWindow autorelease];
    QSObject *window = [QSObject objectForWindow:focusedWindow name:nil process:process appWindows:WindowDictsForApp(process)];
    [focusedWindow release];
    return window;
}

- (QSObject *)appWindows:(QSObject *)dObject activateWindow:(QSObject *)iObject
{
  return [self activateWindow:iObject];
}

- (QSObject *)activateWindow:(QSObject *)dObject
{
  dObject = [self resolvedProxy:dObject];
  id aWindow = [dObject objectForType:kWindowsType];
  if (!aWindow) return nil;
  AXUIElementPerformAction((AXUIElementRef)aWindow,kAXRaiseAction);
	NSRunningApplication *process = [dObject objectForType:kWindowsProcessType];
	if (process) [process activateWithOptions:NSApplicationActivateIgnoringOtherApps];
  return nil;
}

- (QSObject *)raiseWindow:(QSObject *)dObject
{
  dObject = [self resolvedProxy:dObject];
  id aWindow = [dObject objectForType:kWindowsType];
  if (!aWindow) return nil;
  AXUIElementPerformAction((AXUIElementRef)aWindow,kAXRaiseAction);
  return nil;
}

void PressButtonInWindow(id buttonName, id window)
{
  AXUIElementRef button;
  AXUIElementCopyAttributeValue((AXUIElementRef)window,(CFStringRef)buttonName, (CFTypeRef *)&button);
  [(id)button autorelease];
  AXUIElementPerformAction(button,kAXPressAction);
}

- (QSObject *)zoomWindow:(QSObject *)dObject
{
  dObject = [self resolvedProxy:dObject];
  id aWindow = [dObject objectForType:kWindowsType];
  if (!aWindow) return nil;
  PressButtonInWindow((id)kAXZoomButtonAttribute, aWindow);
  return nil;
}

- (QSObject *)minimizeWindow:(QSObject *)dObject
{
  dObject = [self resolvedProxy:dObject];
  id aWindow = [dObject objectForType:kWindowsType];
  if (!aWindow) return nil;
  PressButtonInWindow((id)kAXMinimizeButtonAttribute, aWindow);
  return nil;
}

- (QSObject *)closeWindow:(QSObject *)dObject
{
  dObject = [self resolvedProxy:dObject];
  id aWindow = [dObject objectForType:kWindowsType];
  if (!aWindow) return nil;
  PressButtonInWindow((id)kAXCloseButtonAttribute, aWindow);
  return nil;
}

- (QSObject *)allAppWindows:(QSObject *)dObject
{
    NSArray *runningApps = [[NSWorkspace sharedWorkspace] runningApplications];
    __block NSMutableArray *windows = [NSMutableArray array];
    [runningApps enumerateObjectsWithOptions:NSEnumerationConcurrent usingBlock:^(NSRunningApplication *anApp, NSUInteger idx, BOOL *stop) {
        NSArray *windowObjects = WindowsForApp(anApp, YES);
        if (windowObjects) [windows addObjectsFromArray:windowObjects];
    }];
	[QSPreferredCommandInterface showArray:windows];
	return nil;
}

- (QSObject *)allAppMenus:(QSObject *)dObject
{
    NSArray *launchedApps = [[NSWorkspace sharedWorkspace] runningApplications];
    NSMutableArray *menus = [NSMutableArray array];
    for (NSRunningApplication *process in launchedApps) {
        AXUIElementRef app = AXUIElementCreateApplication([process processIdentifier]);
        AXUIElementRef menuBar;
        AXUIElementCopyAttributeValue(app, kAXMenuBarAttribute, (CFTypeRef *)&menuBar);
        CFRelease(app);
        QSObject *object = [QSObject objectByMergingObjects:MenuItemsForElement(menuBar, 6, nil, nil, 2, process)];
        CFRelease(menuBar);
        [object setName:[process localizedName]];
        [object setIcon:[process icon]];
        [menus addObject:object];
    }
	[QSPreferredCommandInterface showArray:menus];
	return nil;
}

- (QSObject *)activeAppObject
{
  NSDictionary *curAppInfo = [[NSWorkspace sharedWorkspace] activeApplication];
  QSObject *curAppObject = [QSObject fileObjectWithPath:[curAppInfo objectForKey:@"NSApplicationPath"]];
  [curAppObject setName:[curAppInfo objectForKey:@"NSApplicationName"]];
  [curAppObject setObject:curAppInfo forType:QSProcessType];
  return curAppObject;
}

- (QSObject *)focusedWindowObject
{
  return [self focusedWindowForApp:[self activeAppObject]];
}

- (QSObject *)currentDocumentObject
{
  return [self currentDocumentForApp:[self activeAppObject]];
}

- (id)resolveProxyObject:(id)proxy{
  if ([[proxy identifier] isEqualToString:kCurrentFocusedWindowProxy]) return [self focusedWindowObject];
  if ([[proxy identifier] isEqualToString:kCurrentDocumentProxy]) return [self currentDocumentObject];
  return nil;
}

- (NSArray *)validIndirectObjectsForAction:(NSString *)action directObject:(QSObject *)dObject{
	if ([action isEqualToString:@"QSPickMenuItemsAction"]){
        dObject = [self resolvedProxy:dObject];
        id process = [dObject objectForType:QSProcessType];
        if ([process isKindOfClass:[NSDictionary class]]) {
            process = [NSRunningApplication runningApplicationWithProcessIdentifier:[[process objectForKey:@"NSApplicationProcessIdentifier"] intValue]];
        }
		AXUIElementRef app=AXUIElementCreateApplication ([process processIdentifier]);
        if (!app) {
            return nil;
        }
		AXUIElementRef menuBar;
		AXUIElementCopyAttributeValue (app, kAXMenuBarAttribute, (CFTypeRef *)&menuBar);
        CFRelease(app);
        if (!menuBar) {
            return nil;
        }
		NSArray *actions=MenuItemsForElement(menuBar, 6, nil, nil, 2, process);
        CFRelease(menuBar);
		return [NSArray arrayWithObjects:[NSNull null],actions,nil];
	} else if ([action isEqualToString:@"ListWindowsForApp"]) {
        dObject = [self resolvedProxy:dObject];
        id process = [dObject objectForType:QSProcessType];
        if ([process isKindOfClass:[NSDictionary class]]) {
            process = [NSRunningApplication runningApplicationWithProcessIdentifier:[[process objectForKey:@"NSApplicationProcessIdentifier"] intValue]];
        }
        NSArray *windowObjects = WindowsForApp(process, NO);
        return (windowObjects) ? [NSArray arrayWithObjects:[NSNull null],windowObjects,nil] : [NSArray array];
	}
    return nil;
}


- (NSArray *) validActionsForDirectObject:(QSObject *)dObject indirectObject:(QSObject *)iObject{
	AXUIElementRef element= (AXUIElementRef)[dObject objectForType:kQSUIElementType];
	NSArray *actions=nil;
	AXUIElementCopyActionNames (element, (CFArrayRef *)&actions);
	[(id)actions autorelease];
	if ([actions containsObject:(NSString *)kAXPickAction])
		return [NSArray arrayWithObject:@"QSUIElementPickAction"];
	if ([actions containsObject:(NSString *)kAXPressAction])
		return [NSArray arrayWithObject:@"QSUIElementPressAction"];
	return nil;
}

- (QSObject *)uiElement:(QSObject *)dObject performAction:(QSObject *)iObject{
	AXUIElementRef element= (AXUIElementRef)[dObject objectForType:kQSUIElementType];
	[self activateProcessOfElement:element];
	AXUIElementPerformAction (element, (CFStringRef)[iObject objectForType:kQSUIActionType]);
	return nil;
}

- (QSObject *)pressUIElement:(QSObject *)dObject{
	AXUIElementRef element= (AXUIElementRef)[dObject objectForType:kQSUIElementType];
	[self activateProcessOfElement:element];
	AXUIElementPerformAction (element, kAXPressAction);
	return nil;
}
- (void)activateProcessOfElement:(AXUIElementRef) element{
	pid_t pid=-1;
	AXUIElementGetPid (element, &pid);
	ProcessSerialNumber psn;
	GetProcessForPID(pid,&psn);
	SetFrontProcessWithOptions (&psn,kSetFrontProcessFrontWindowOnly);
}
- (QSObject *)pickUIElement:(QSObject *)dObject{
	AXUIElementRef element= (AXUIElementRef)[dObject objectForType:kQSUIElementType];
	[self activateProcessOfElement:element];
	AXUIElementPerformAction (element,kAXPressAction);
	return nil;
}

- (QSObject *)resolvedProxy:(QSObject *)dObject
{
    if ([dObject respondsToSelector:@selector(resolvedObject)]) {
        return [dObject resolvedObject];
    }
    if ([dObject respondsToSelector:@selector(object)]) {
      return [self resolvedProxy:[(QSRankedObject *)dObject object]];
    }
  return dObject;
}

- (QSObject *)currentDocumentForApp:(QSObject *)appObject
{
  NSDictionary *process = [[self resolvedProxy:appObject] objectForType:QSProcessType];
  pid_t pid = [[process objectForKey:@"NSApplicationProcessIdentifier"] intValue];
  AXUIElementRef app = AXUIElementCreateApplication(pid);
  AXUIElementRef window = nil;
  AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute, (CFTypeRef *)&window);
    [(id)app release];
    if ([self firstDocumentObjectForElement:window depth:3 title:nil]) {
        return [self firstDocumentObjectForElement:window depth:3 title:nil];
    }
    CFRelease(window);
    return nil;
}

- (QSObject *)firstDocumentObjectForElement:(AXUIElementRef)element depth:(NSInteger)depth title:(NSString *)title
{
    if (depth != 0) {
        NSString *currentPath = nil;
        AXUIElementCopyAttributeValue(element, kAXDocumentAttribute, (CFTypeRef *)&currentPath);
        [currentPath autorelease];
        if (currentPath) return [QSObject fileObjectWithPath:[[NSURL URLWithString:currentPath] path]];
        
        if (!title)
        {
            AXUIElementCopyAttributeValue(element, kAXTitleAttribute, (CFTypeRef *)&title);
            [title autorelease];
        }
        
        NSURL *currentURL = nil;
        AXUIElementCopyAttributeValue(element, kAXURLAttribute, (CFTypeRef *)&currentURL);
        [currentURL autorelease];
        if (currentURL)
        {
            if ([currentURL isFileURL]) return [QSObject fileObjectWithPath:[currentURL path]];
            return [QSObject URLObjectWithURL:[currentURL description] title:title];
        }
        
        NSArray *children = nil;
        AXUIElementCopyAttributeValue(element, kAXChildrenAttribute, (CFTypeRef *)&children);
        [children autorelease];
        if ([children count] == 0) return nil;
        for (id child in children)
        {
            AXUIElementCopyAttributeValue((AXUIElementRef)child, kAXDocumentAttribute, (CFTypeRef *)&currentPath);
            [currentPath autorelease];
            if (currentPath) return [QSObject fileObjectWithPath:[[NSURL URLWithString:currentPath] path]];
            
            AXUIElementCopyAttributeValue((AXUIElementRef)child, kAXURLAttribute, (CFTypeRef *)&currentURL);
            [currentURL autorelease];
            if (currentURL)
            {
                if ([currentURL isFileURL]) return [QSObject fileObjectWithPath:[currentURL path]];
                return [QSObject URLObjectWithURL:[currentURL description] title:title];
            }
            
            QSObject *childDoc = [self firstDocumentObjectForElement:(AXUIElementRef)child depth:depth - 1 title:title];
            if (childDoc) return childDoc;
        }
    }
    NSBeep();
    return nil;
}

- (void)selectAndDisplayObject:(QSObject *)object
{
  if (object) [QSPreferredCommandInterface executePartialCommand:[NSArray arrayWithObject:object]];
  else NSBeep();
}

- (QSObject *)fetchCurrentFocusedWindow
{
  [self selectAndDisplayObject:[self focusedWindowObject]];
  return nil;
}

- (QSObject *)fetchCurrentDocument
{
  [self selectAndDisplayObject:[self currentDocumentObject]];
  return nil;
}

- (QSObject *)fetchCurrentApp
{
  [self selectAndDisplayObject:[self activeAppObject]];
  return nil;
}

@end
