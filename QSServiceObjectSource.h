//
// Created by Tony Papale on 3/29/14.
//

#define QSBridgeServiceObjectTextType           @"QSBridgeServiceObjectTextType"
#define QSBridgeServiceObjectTextSearchType     @"QSBridgeServiceObjectTextSearchType"
#define QSBridgeServiceObjectFileType           @"QSBridgeServiceObjectFileType"
#define QSBridgeServiceObjectFilePathType       @"QSBridgeServiceObjectFilePathType"
#define QSBridgeServiceObjectEmailType          @"QSBridgeServiceObjectEmailType"
#define QSBridgeServiceObjectURLType            @"QSBridgeServiceObjectURLType"
#define QSBridgeServiceObjectAddressType        @"QSBridgeServiceObjectAddressType"


#define kQSReverseServicesIDPrefix              @"reverse-service-action:"
#define kQSReverseServicesServiceBundle         @"kQSReverseServicesServiceBundle"

@interface QSServiceObjectSource : QSObjectSource

+ (NSArray *) getActiveObjectTypes;

@end