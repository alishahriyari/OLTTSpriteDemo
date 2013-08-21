//
//  OLAntagonist.h
//  OLTTSpriteDemo
//
//  Created by Ali Shahriyari on 8/19/13.
//  Copyright (c) 2013 Originate. All rights reserved.
//

#import <SpriteKit/SpriteKit.h>

@interface OLAntagonist : SKSpriteNode

@property BOOL isIntern;
@property BOOL isAnimating;
@property BOOL isFaster;
@property BOOL isDeadOrHiding;
@property (nonatomic) CGPoint initialPosition;

@end
