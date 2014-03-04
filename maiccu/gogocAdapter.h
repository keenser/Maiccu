//
//  gogocAdapter.h
//  maiccu
//
//  Created by German Skalauhov on 30/01/2014.
//  Copyright (c) 2014 Kristof Hannemann. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "genericAdapter.h"

@interface gogocAdapter : genericAdapter {
@private
    NSMutableDictionary *gTunnelInfo;
    NSDictionary *gTunnelList;
}

- (oneway void) print:(NSDictionary*)message;
- (oneway void) statusUpdate:(gogocStatusInfo*)gStatusInfo;
- (oneway void) tunnelUpdate:(gogocTunnelInfo*)gTunnelInfo;
- (oneway void) brokerUpdate:(gogocBrokerList*)gBrokerList;

@end
