//
//  FrameSelectionViewController.h
//  Kite Print SDK
//
//  Created by Deon Botha on 13/02/2014.
//  Copyright (c) 2014 Ocean Labs. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "OLKiteViewController.h"

@class OLPrintOrder;

@interface OLFrameSelectionViewController : UITableViewController

@property (strong, nonatomic) NSMutableArray *assets;
@property (strong, nonatomic) NSMutableArray *userSelectedPhotos;
@property (weak, nonatomic) id<OLKiteDelegate> delegate;

// A set of product template_id strings which if present will restrict which products ultimate show up in the product selection journey
@property (copy, nonatomic) NSSet/*<NSString>*/ *filterProducts;

@end
