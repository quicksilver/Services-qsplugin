//
// Created by Tony Papale on 3/29/14.
//

#import "QSBridgeServiceAction.h"
#import "QSServiceObjectSource.h"
#import "QSServiceAction.h"


@implementation QSBridgeServiceAction

- (NSArray *) createBridgeServiceAction
{
    NSMutableArray *bridgeActions = [NSMutableArray array];

    QSAction *newAction = [[QSAction alloc] init];
    [newAction setIdentifier:[NSString stringWithFormat:@"%@With...", kQSReverseServicesIDPrefix]];
    [newAction setName:[NSString stringWithFormat:@"With..."]];
    [newAction setDirectTypes:[QSServiceObjectSource getActiveObjectTypes]];
    [newAction setArgumentCount:2];
    [newAction setBundle:[NSBundle bundleWithIdentifier:kBundleID]];
    [newAction setIcon:[QSResourceManager imageNamed:@"Find"]];
    [newAction setIconLoaded:YES];
    [newAction setRetainsIcon:YES];
    [newAction setProvider:self];
    [newAction setDisplaysResult:YES];
    [newAction setDetails:[NSString stringWithFormat:@"A reverse action from the service plugin"]];
    [bridgeActions addObject:newAction];
    return bridgeActions;
}

- (NSArray *) validIndirectObjectsForAction:(NSString *)action directObject:(QSObject *)dObject
{
    if ([dObject.primaryType isEqualToString:QSBridgeServiceObjectTextSearchType])
    {
        NSString *searchString = [[NSPasteboard pasteboardWithName:NSFindPboard] stringForType:NSStringPboardType];
        return [NSArray arrayWithObject:[QSObject textProxyObjectWithDefaultValue:searchString]];
    }
    else if ([dObject.primaryType isEqualToString:QSBridgeServiceObjectTextType])
    {
        return [QSLib arrayForType:NSStringPboardType];
    }
    else if ([dObject.primaryType isEqualToString:QSBridgeServiceObjectEmailType])
    {
        return [QSLib arrayForType:QSEmailAddressType];
    }
    else if ([dObject.primaryType isEqualToString:QSBridgeServiceObjectURLType])
    {
        return [QSLib arrayForType:QSURLType];
    }
    else if ([dObject.primaryType isEqualToString:QSBridgeServiceObjectFilePathType])
    {
        // TODO: copied directly from FSActions in QSActionProvider_EmbeddedProviders.m, should be a QSFolderType?
        // We only want folders for the move to / copy to actions (can't move to anything else)
        NSArray *fileObjects = [[QSLibrarian sharedInstance] arrayForType:QSFilePathType];
        NSString *currentFolderPath = [[[dObject validPaths] lastObject] stringByDeletingLastPathComponent];

        // if the parent directory was found, put it first - otherwise, leave the pane blank
        id currentFolderObject = currentFolderPath ? [QSObject fileObjectWithPath:currentFolderPath] : [NSNull null];

        NSIndexSet *folderIndexes = [fileObjects indexesOfObjectsWithOptions:NSEnumerationConcurrent passingTest:^BOOL(QSObject *thisObject, NSUInteger i, BOOL *stop)
        {
            QSObject *resolved = [thisObject resolvedAliasObject];
            return ([resolved isFolder] && (thisObject != currentFolderObject));
        }];

        return [[NSArray arrayWithObject:currentFolderObject]
                         arrayByAddingObjectsFromArray:[fileObjects objectsAtIndexes:folderIndexes]];
    }

    return [QSLib arrayForType:QSFilePathType];
}

- (QSObject *) performAction:(QSAction *)action
                directObject:(QSBasicObject *)dObject
              indirectObject:(QSBasicObject *)iObject
{
    NSPasteboard *pboard = [NSPasteboard pasteboardWithUniqueName];
    //NSLog(@"perform %@ %@ %@",[action actionDict],serviceArray,self);

    @autoreleasepool
    {
        // NSLog(@"'%@' '%@'",[action identifier],[[thisService objectForKey:NSMenuItemKey]objectForKey:DefaultKey]);
        @try
        {
            NSArray *sendTypes = [((QSObject *) dObject) objectForMeta:NSSendTypesKey];

            if ([dObject.primaryType isEqualToString:QSBridgeServiceObjectFileType])
            {
//                sendTypes = [sendTypes arrayByAddingObject:NSFilenamesPboardType];
                sendTypes = [sendTypes arrayByAddingObject:QSFilePathType];
            }

            [iObject putOnPasteboard:pboard declareTypes:sendTypes includeDataForTypes:sendTypes];

        }
        @catch (NSException *exception)
        {
            NSLog(@"Exception: %@ in service array: %@", exception, dObject.name);
        }
    }

    BOOL success = NSPerformService([dObject.identifier stringByReplacing:kQSReverseServicesIDPrefix with:@""], pboard);
    if (success)
    {
        QSObject *entry = nil;
        if ([((QSObject *) dObject) objectForMeta:NSReturnTypesKey])
        {
            entry = [[QSObject alloc]
                               initWithPasteboard:pboard types:[((QSObject *) dObject) objectForMeta:NSReturnTypesKey]];
        }
        return entry;
    }
//    NSLog(@"PerformServiceFailed: %@, %@\r%@\r%@", action, dObject, serviceBundle, [[pboard types] componentsJoinedByString:@", "]);

    return nil;
}

- (BOOL) performServiceWithNameAndPasteboard:(NSArray *)array
{
    return NSPerformService([array objectAtIndex:0], [array lastObject]);
}

@end