//
//  TKZAiccuAdapter.h
//  maiccu
//
//  Created by Kristof Hannemann on 04.05.13.
//  Copyright (c) 2013 Kristof Hannemann. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "genericAdapter.h"

@interface TKZAiccuAdapter : genericAdapter {
@private
    struct TIC_conf	*tic;
    NSMutableDictionary *_tunnelList;
}

@end
