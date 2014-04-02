//
// Created by Tony Papale on 3/29/14.
//

#import "QSServiceObjectSource.h"
#import "QSServiceAction.h"

@implementation QSServiceObjectSource

+ (NSArray *) getActiveObjectTypes
{
    return @[QSBridgeServiceObjectTextType,
            QSBridgeServiceObjectFileType,
            QSBridgeServiceObjectAddressType,
            QSBridgeServiceObjectURLType,
            QSBridgeServiceObjectEmailType,
            QSBridgeServiceObjectFilePathType
    ];
}

// if this returns FALSE, the source will be rescanned
// if it returns TRUE, the source is left alone
// unconditional returns will cause it to either be scanned every time, or never
- (BOOL) indexIsValidFromDate:(NSDate *)indexDate forEntry:(NSDictionary *)theEntry
{
    // if we fall through to this point, don't rescan by default
    return NO;
}

- (NSImage *) iconForEntry:(NSDictionary *)theEntry
{
    return [QSResourceManager imageNamed:@"Menu"];
}

- (NSArray *) objectsForEntry:(NSDictionary *)theEntry
{
//    NSMutableArray *catalogObjects = [NSMutableArray array];
    NSMutableSet *catalogObjects = [NSMutableSet set];

    NSArray *serviceActions = [QSServiceActions allServiceActions];
//    NSArray *serviceActions = [QSExec actions];

    for (QSServiceActions *serviceAction in serviceActions)
    {
        NSImage *actionIcon = [[NSWorkspace sharedWorkspace] iconForFile:serviceAction.serviceBundle];
        [actionIcon setSize:NSMakeSize(16, 16)];
        NSBundle *servicesBundle = [NSBundle bundleWithIdentifier:kBundleID];
        NSString *serviceString = nil;
        NSString *modServiceString = nil;

        for (NSDictionary *thisService in serviceAction.serviceArray)
        {
            @try
            {
                serviceString = [[thisService objectForKey:NSMenuItemKey] objectForKey:DefaultKey];
            }
            @catch (NSException *exception)
            {
                NSLog(@"Exception: %@ for service array: %@", exception, serviceAction.serviceArray);
            }

            if (!serviceString)
            {
                continue;
            }
            NSDictionary *serviceModifications = [serviceAction.modificationsDictionary objectForKey:serviceString];

            if ([[serviceModifications objectForKey:@"disabled"] boolValue])
            {
                continue;
            }

            if ([serviceModifications objectForKey:@"name"])
            {
                modServiceString = [serviceModifications objectForKey:@"name"];
            }


            NSArray *sendTypes = [thisService objectForKey:NSSendTypesKey];
            NSArray *fileSendTypes = [thisService objectForKey:NSSendFilesTypesKey];

            // make sure this action responds to a min of text or files
            if (![self shouldAddServiceAction:thisService])
            {
                continue;
            }


            QSObject *serviceObject = [[QSObject alloc] init];
            [serviceObject setIdentifier:[NSString stringWithFormat:@"%@%@", kQSReverseServicesIDPrefix, serviceString]];
            [serviceObject setName:modServiceString ? modServiceString : serviceString];
            [serviceObject setBundle:servicesBundle];
            [serviceObject setIcon:actionIcon];
            [serviceObject setIconLoaded:YES];
            [serviceObject setRetainsIcon:YES];
            [serviceObject setDetails:[NSString stringWithFormat:@"A service of %@", [serviceAction.serviceBundle lastPathComponent]]];
            [serviceObject setObject:serviceAction.serviceBundle forMeta:kQSReverseServicesServiceBundle];

            // check if there is an override for the service name
            if ([serviceModifications objectForKey:@"name"])
            {
                [serviceObject setName:[serviceModifications objectForKey:@"name"]];
            }


//            NSLog(@"-----------------------------\n%@:%@", serviceString, thisService);
            if (sendTypes && sendTypes.count > 0)
            {
                // This is a **dirty hack** to deal with Quicksilver's lack of UTI support. public.utf8-plaint-text = NSStringPboardType
                if ([sendTypes containsObject:NSStringPboardType])
                {
                    [serviceObject setObject:serviceObject.name forType:QSBridgeServiceObjectTextType];
                    [serviceObject setPrimaryType:QSBridgeServiceObjectTextType];
                }

                if ([sendTypes containsObject:NSURLPboardType])
                {
                    [serviceObject setObject:serviceObject.name forType:QSBridgeServiceObjectURLType];
                    [serviceObject setPrimaryType:QSBridgeServiceObjectURLType];
                }

                if ([sendTypes containsObject:NSFilenamesPboardType])
                {
                    [serviceObject setObject:serviceObject.name forType:QSBridgeServiceObjectFilePathType];
                    [serviceObject setPrimaryType:QSBridgeServiceObjectFilePathType];
                }

                [serviceObject setObject:sendTypes forMeta:NSSendTypesKey];
            }

            // If the service is for specific file types, add file types
            if (fileSendTypes && fileSendTypes.count > 0)
            {
                [serviceObject setObject:serviceObject.name forType:QSBridgeServiceObjectFileType];
                [serviceObject setPrimaryType:QSBridgeServiceObjectFileType];

                [serviceObject setObject:fileSendTypes forMeta:NSSendFilesTypesKey];
            }

            id requiredContext = [thisService objectForKey:@"NSRequiredContext"];
//                NSLog(@"%@ - NSRequiredContext:%@", serviceString, [thisService objectForKey:@"NSRequiredContext"] ? [thisService objectForKey:@"NSRequiredContext"] : @"Empty");

            if (requiredContext && [requiredContext count] > 0)
            {
                NSArray *reqContextArray = [NSArray array];
                if ([requiredContext isKindOfClass:[NSDictionary class]])
                {
                    reqContextArray = [NSArray arrayWithObject:requiredContext];
                }
                else if ([requiredContext isKindOfClass:[NSArray class]])
                {
                    reqContextArray = requiredContext;
                }

                // TODO: add more contexts here?
                for (NSDictionary *reqContextDict in reqContextArray)
                {
                    if ([reqContextDict isKindOfClass:[NSDictionary class]])
                    {
                        if ([[reqContextDict objectForKey:@"NSTextContent"] isEqualToString:@"Address"])
                        {
                            [serviceObject setObject:serviceObject.name forType:QSBridgeServiceObjectAddressType];
                            [serviceObject setPrimaryType:QSBridgeServiceObjectAddressType];
                        }
                        else if ([[reqContextDict objectForKey:@"NSTextContent"] isEqualToString:@"URL"])
                        {
                            [serviceObject setObject:serviceObject.name forType:QSBridgeServiceObjectURLType];
                            [serviceObject setPrimaryType:QSBridgeServiceObjectURLType];
                        }
                        else if ([[reqContextDict objectForKey:@"NSTextContent"] isEqualToString:@"FilePath"])
                        {
                            [serviceObject setObject:serviceObject.name forType:QSBridgeServiceObjectFilePathType];
                            [serviceObject setPrimaryType:QSBridgeServiceObjectFilePathType];
                        }
                        else if ([[reqContextDict objectForKey:@"NSSearchCategory"] rangeOfString:@"Search"].location != NSNotFound)
                        {
                            [serviceObject setObject:serviceObject.name forType:QSBridgeServiceObjectTextSearchType];
                            [serviceObject setPrimaryType:QSBridgeServiceObjectTextSearchType];
                        }
                    }
                }
            }

            if ([thisService objectForKey:NSReturnTypesKey])
            {
                [serviceObject setObject:[thisService objectForKey:NSReturnTypesKey] forMeta:NSReturnTypesKey];
            }

            // TODO: Not sure why the QSObject isEqual: isn't catching this?
            if (![self doesSet:catalogObjects containObject:serviceObject])
            {
                [catalogObjects addObject:serviceObject];
            }
        }
    }

    return [catalogObjects allObjects];
}

- (BOOL) shouldAddServiceAction:(NSDictionary *)theService
{
    NSArray *sendTypes = [theService objectForKey:NSSendTypesKey];
    NSArray *fileSendTypes = [theService objectForKey:NSSendFilesTypesKey];

    // make sure this action responds to a min of text or files
    if ([sendTypes containsObject:@"public.utf8-plain-text"])
    {
        return YES;

    }
    else if ([sendTypes containsObject:NSStringPboardType])
    {
        return YES;
    }
    else if ([sendTypes containsObject:NSFilenamesPboardType])
    {
        return YES;
    }
    else if (fileSendTypes && [fileSendTypes count] > 0)
    {
        return YES;
    }

    return NO;
}

- (BOOL) doesSet:(NSMutableSet *)theSet containObject:(QSObject *)theObject
{
    for (QSObject *catalogObject in theSet)
    {
        if ([catalogObject.identifier isEqualToString:theObject.identifier])
        {
//            NSLog(@"Set already contains object %@", theObject.name);
            return YES;
        }
    }
    return NO;
}

- (BOOL) objectHasChildren:(QSObject *)object
{
    return NO;
}

- (BOOL) loadChildrenForObject:(QSObject *)object
{
    return NO;
}

@end